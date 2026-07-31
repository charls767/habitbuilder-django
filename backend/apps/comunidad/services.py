"""Casos de uso de 'comunidad' (espejo de internal/comunidad).

Reglas replicadas:
  - contenido recortado: publicación 1..1000 runas, comentario 1..500.
  - el feed y las lecturas solo ven publicaciones visibles y no eliminadas
    (estado_moderacion='visible' AND eliminado_en IS NULL).
  - editar/eliminar solo el autor; ajeno responde 404 indistinguible.
  - reaccionar es idempotente (PK compuesta, conflicto se ignora).
  - reporte duplicado → 409 codigo report_already_exists.
  - habitoId en publicación: uuid inválido → 400 'habito invalido'; no
    propio/eliminado → 404 'habito no encontrado'.
"""
from django.db import IntegrityError, transaction
from django.db.models import Count, Exists, IntegerField, OuterRef, Subquery
from django.db.models.functions import Coalesce
from django.utils import timezone

from apps.habitosymetas.models import Habito
from apps.plataforma.api.exceptions import ContractError

from .models import (
    ComentarioComunidad,
    PublicacionComunidad,
    ReaccionComunidad,
    ReporteComunidad,
)

MAX_PUBLICACION_RUNAS = 1000
MAX_COMENTARIO_RUNAS = 500
MOTIVOS_VALIDOS = {"spam", "acoso", "inapropiado", "otro"}

MENSAJE_VALIDACION = "la solicitud contiene errores de validacion"
MENSAJE_PUBLICACION_404 = "publicacion no encontrada"
MENSAJE_COMENTARIO_404 = "comentario no encontrado"
MENSAJE_HABITO_404 = "habito no encontrado"
MENSAJE_HABITO_INVALIDO = "habito invalido"
MENSAJE_PAGINACION = "parametros de paginacion invalidos"
MENSAJE_REPORTE_DUPLICADO = "la publicacion ya fue reportada por este usuario"


def _error_validacion() -> ContractError:
    return ContractError(MENSAJE_VALIDACION, status_code=400, codigo="invalid_request")


def _publicacion_404() -> ContractError:
    return ContractError(MENSAJE_PUBLICACION_404, status_code=404, codigo="not_found")


def _validar_contenido(raw, maximo: int) -> str:
    if not isinstance(raw, str):
        raise _error_validacion()
    valor = raw.strip()
    if not valor or len(valor) > maximo:
        raise _error_validacion()
    return valor


def _visibles():
    return PublicacionComunidad.objects.filter(
        eliminado_en__isnull=True, estado_moderacion="visible"
    )


def _con_contadores(qs, usuario):
    """Subconsultas correlacionadas, como el SELECT del repositorio Go."""
    reacciones = (
        ReaccionComunidad.objects.filter(publicacion=OuterRef("pk"))
        .values("publicacion")
        .annotate(n=Count("usuario"))
        .values("n")
    )
    comentarios = (
        ComentarioComunidad.objects.filter(
            publicacion=OuterRef("pk"), eliminado_en__isnull=True
        )
        .values("publicacion")
        .annotate(n=Count("id"))
        .values("n")
    )
    return qs.select_related("usuario").annotate(
        n_reacciones=Coalesce(
            Subquery(reacciones, output_field=IntegerField()), 0
        ),
        n_comentarios=Coalesce(
            Subquery(comentarios, output_field=IntegerField()), 0
        ),
        reaccionada_por_mi=Exists(
            ReaccionComunidad.objects.filter(
                publicacion=OuterRef("pk"), usuario=usuario
            )
        ),
    )


def obtener_publicacion(usuario, publicacion_id_raw) -> PublicacionComunidad:
    from apps.habitosymetas.services import parse_uuid

    pid = parse_uuid(publicacion_id_raw, _publicacion_404())
    publicacion = _con_contadores(_visibles(), usuario).filter(id=pid).first()
    if publicacion is None:
        raise _publicacion_404()
    return publicacion


def listar_feed(usuario, *, limit_raw, offset_raw):
    # Paridad Go: strconv falla → "parametros de paginacion invalidos";
    # fuera de rango → el service responde el 400 de validacion genérico.
    try:
        limit = int(limit_raw) if limit_raw not in (None, "") else 20
        offset = int(offset_raw) if offset_raw not in (None, "") else 0
    except (TypeError, ValueError):
        raise ContractError(
            MENSAJE_PAGINACION, status_code=400, codigo="invalid_request"
        ) from None
    if limit < 1 or limit > 50 or offset < 0:
        raise _error_validacion()
    qs = _con_contadores(_visibles(), usuario).order_by("-creado_en")
    return list(qs[offset:offset + limit])


def crear_publicacion(usuario, *, contenido, habito_id_raw) -> PublicacionComunidad:
    from apps.habitosymetas.services import parse_uuid

    contenido_valido = _validar_contenido(contenido, MAX_PUBLICACION_RUNAS)
    habito = None
    if habito_id_raw is not None:
        hid = parse_uuid(
            habito_id_raw,
            ContractError(MENSAJE_HABITO_INVALIDO, status_code=400,
                          codigo="invalid_request"),
        )
        habito = Habito.objects.filter(
            id=hid, usuario=usuario, eliminado_en__isnull=True
        ).first()
        if habito is None:
            raise ContractError(MENSAJE_HABITO_404, status_code=404, codigo="not_found")
    creada = PublicacionComunidad.objects.create(
        usuario=usuario, contenido=contenido_valido, habito=habito
    )
    return obtener_publicacion(usuario, str(creada.id))


def editar_publicacion(usuario, publicacion_id_raw, *, contenido) -> PublicacionComunidad:
    publicacion = obtener_publicacion(usuario, publicacion_id_raw)
    if publicacion.usuario_id != usuario.id:
        raise _publicacion_404()  # nunca 403: indistinguible
    publicacion.contenido = _validar_contenido(contenido, MAX_PUBLICACION_RUNAS)
    publicacion.actualizado_en = timezone.now()
    publicacion.save(update_fields=["contenido", "actualizado_en"])
    return obtener_publicacion(usuario, publicacion_id_raw)


def eliminar_publicacion(usuario, publicacion_id_raw) -> None:
    from apps.habitosymetas.services import parse_uuid

    pid = parse_uuid(publicacion_id_raw, _publicacion_404())
    actualizadas = _visibles().filter(id=pid, usuario=usuario).update(
        eliminado_en=timezone.now()
    )
    if actualizadas == 0:
        raise _publicacion_404()


def listar_comentarios(usuario, publicacion_id_raw):
    publicacion = obtener_publicacion(usuario, publicacion_id_raw)
    return list(
        ComentarioComunidad.objects.filter(
            publicacion=publicacion, eliminado_en__isnull=True
        )
        .select_related("usuario")
        .order_by("creado_en")
    )


def crear_comentario(usuario, publicacion_id_raw, *, contenido) -> ComentarioComunidad:
    publicacion = obtener_publicacion(usuario, publicacion_id_raw)
    return ComentarioComunidad.objects.create(
        publicacion=publicacion,
        usuario=usuario,
        contenido=_validar_contenido(contenido, MAX_COMENTARIO_RUNAS),
    )


def eliminar_comentario(usuario, comentario_id_raw) -> None:
    from apps.habitosymetas.services import parse_uuid

    error = ContractError(MENSAJE_COMENTARIO_404, status_code=404, codigo="not_found")
    cid = parse_uuid(comentario_id_raw, error)
    actualizados = ComentarioComunidad.objects.filter(
        id=cid, usuario=usuario, eliminado_en__isnull=True
    ).update(eliminado_en=timezone.now())
    if actualizados == 0:
        raise error


def reaccionar(usuario, publicacion_id_raw) -> None:
    publicacion = obtener_publicacion(usuario, publicacion_id_raw)
    try:
        with transaction.atomic():
            ReaccionComunidad.objects.create(publicacion=publicacion, usuario=usuario)
    except IntegrityError:
        pass  # idempotente: la reacción ya existía


def quitar_reaccion(usuario, publicacion_id_raw) -> None:
    publicacion = obtener_publicacion(usuario, publicacion_id_raw)
    ReaccionComunidad.objects.filter(publicacion=publicacion, usuario=usuario).delete()


def crear_reporte(usuario, publicacion_id_raw, *, motivo, detalle) -> ReporteComunidad:
    publicacion = obtener_publicacion(usuario, publicacion_id_raw)

    motivo_valido = motivo.strip() if isinstance(motivo, str) else ""
    if motivo_valido not in MOTIVOS_VALIDOS:
        raise _error_validacion()
    detalle_valido = ""
    if detalle is not None:
        if not isinstance(detalle, str):
            raise _error_validacion()
        detalle_valido = detalle.strip()
        if len(detalle_valido) > 500:
            raise _error_validacion()

    try:
        with transaction.atomic():
            return ReporteComunidad.objects.create(
                publicacion=publicacion,
                reportante=usuario,
                motivo=motivo_valido,
                detalle=detalle_valido or None,
            )
    except IntegrityError:
        raise ContractError(
            MENSAJE_REPORTE_DUPLICADO, status_code=409, codigo="report_already_exists"
        ) from None
