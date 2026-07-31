"""Casos de uso de 'administración' (espejo de internal/administracion y de
la moderación de internal/comunidad montada bajo /v1/admin).

Reglas replicadas:
  - Protección de último administrador: no se puede suspender ni degradar
    al único admin activo → 409 last_admin_protection.
  - Un admin no puede cambiarse su propio estado/rol (400 validacion).
  - Toda acción administrativa deja rastro en auditoria_administrativa.
  - Aprobar una solicitud promueve al usuario a rol admin en la misma
    transacción; resolver una no pendiente → 409 request_conflict.
  - Moderación: 'aprobar' descarta el reporte y deja el post visible;
    'ocultar' lo resuelve y oculta el post. Resolver un reporte no
    pendiente reutiliza (como Go) el 409 report_already_exists.
"""
from datetime import date, datetime, timedelta
from datetime import timezone as dt_timezone

from django.db import transaction
from django.utils import timezone

from apps.identidad.models import Usuario
from apps.plataforma.api.exceptions import ContractError

from .models import AuditoriaAdministrativa, SolicitudAdministrativa

MENSAJE_VALIDACION = "la solicitud contiene errores de validacion"
MENSAJE_USUARIO_404 = "usuario no encontrado"
MENSAJE_ULTIMO_ADMIN = "no se puede desactivar el ultimo administrador"
MENSAJE_SOLICITUD_404 = "solicitud administrativa no encontrada"
MENSAJE_SOLICITUD_CONFLICTO = (
    "la solicitud administrativa ya fue resuelta o esta pendiente"
)


def _error_validacion() -> ContractError:
    return ContractError(MENSAJE_VALIDACION, status_code=400, codigo="invalid_request")


def _usuario_404() -> ContractError:
    return ContractError(MENSAJE_USUARIO_404, status_code=404, codigo="not_found")


def _validar_razon(razon) -> str:
    if not isinstance(razon, str):
        raise _error_validacion()
    recortada = razon.strip()
    if not recortada or len(recortada) > 500:
        raise _error_validacion()
    return recortada


def _parse_paginacion(limit_raw, offset_raw, *, limit_default, limit_max):
    try:
        limit = int(limit_raw) if limit_raw not in (None, "") else limit_default
        offset = int(offset_raw) if offset_raw not in (None, "") else 0
    except (TypeError, ValueError):
        raise _error_validacion() from None
    if limit < 1 or limit > limit_max or offset < 0:
        raise _error_validacion()
    return limit, offset


# ---------------------------------------------------------------------------
# Usuarios
# ---------------------------------------------------------------------------
def listar_usuarios(*, estado_raw, rol_raw, buscar_raw, limit_raw, offset_raw):
    """Paridad con ListarConFiltros de Go, quirks incluidos: solo `rol` se
    valida contra el enum; un `estado` fuera de enum simplemente no matchea
    (200 []); limit/offset van directo al SQL sin validar rango — un valor
    negativo revienta en Postgres → 500 'error interno', igual que Go."""
    try:
        limit = int(limit_raw) if limit_raw not in (None, "") else 50
        offset = int(offset_raw) if offset_raw not in (None, "") else 0
    except (TypeError, ValueError):
        raise _error_validacion() from None
    if rol_raw not in (None, "") and rol_raw not in ("regular", "admin"):
        raise _error_validacion()
    if limit < 0 or offset < 0:
        raise ContractError("error interno", status_code=500)

    qs = Usuario.objects.all()
    if estado_raw not in (None, ""):
        qs = qs.filter(estado=estado_raw)  # sin validar: fuera de enum → []
    if rol_raw not in (None, ""):
        qs = qs.filter(rol=rol_raw)
    buscar = (buscar_raw or "").strip()
    if buscar:
        from django.db.models import Q

        qs = qs.filter(Q(nombre__icontains=buscar) | Q(email__icontains=buscar))
    return list(qs.order_by("-creado_en", "id")[offset:offset + limit])


def _es_ultimo_admin_activo(target: Usuario) -> bool:
    if not (target.rol == "admin" and target.estado == "activo"):
        return False
    return Usuario.objects.filter(rol="admin", estado="activo").count() <= 1


def _auditar(actor, objetivo, accion: str, razon: str) -> None:
    AuditoriaAdministrativa.objects.create(
        actor=actor, objetivo=objetivo, accion=accion, razon=razon
    )


def cambiar_estado_usuario(actor: Usuario, target_id_raw, *, estado, razon) -> None:
    from apps.habitosymetas.services import parse_uuid

    tid = parse_uuid(target_id_raw, _usuario_404())
    if actor.id == tid or estado not in ("activo", "suspendido"):
        raise _error_validacion()
    target = Usuario.objects.filter(id=tid).first()
    if estado == "suspendido" and target is not None and _es_ultimo_admin_activo(target):
        raise ContractError(
            MENSAJE_ULTIMO_ADMIN, status_code=409, codigo="last_admin_protection"
        )
    razon_valida = _validar_razon(razon)
    if target is None:
        raise _usuario_404()
    with transaction.atomic():
        target.estado = estado
        target.save(update_fields=["estado"])
        _auditar(actor, target, "cambiar_estado", razon_valida)


def cambiar_rol_usuario(actor: Usuario, target_id_raw, *, rol, razon) -> None:
    from apps.habitosymetas.services import parse_uuid

    tid = parse_uuid(target_id_raw, _usuario_404())
    if actor.id == tid or rol not in ("regular", "admin"):
        raise _error_validacion()
    target = Usuario.objects.filter(id=tid).first()
    if rol == "regular" and target is not None and _es_ultimo_admin_activo(target):
        raise ContractError(
            MENSAJE_ULTIMO_ADMIN, status_code=409, codigo="last_admin_protection"
        )
    razon_valida = _validar_razon(razon)
    if target is None:
        raise _usuario_404()
    with transaction.atomic():
        target.rol = rol
        target.save(update_fields=["rol"])
        _auditar(actor, target, "cambiar_rol", razon_valida)


# ---------------------------------------------------------------------------
# Reporte de uso
# ---------------------------------------------------------------------------
def obtener_reporte_uso(*, desde_raw, hasta_raw) -> dict:
    """periodoReporte: hasta=now, desde=now-30d por defecto; fechas
    YYYY-MM-DD; desde > hasta → 400. Rango semiabierto [desde, hasta)."""
    hasta = timezone.now()
    desde = hasta - timedelta(days=30)
    try:
        if desde_raw not in (None, ""):
            desde = datetime.combine(
                date.fromisoformat(str(desde_raw)), datetime.min.time(), dt_timezone.utc
            )
        if hasta_raw not in (None, ""):
            hasta = datetime.combine(
                date.fromisoformat(str(hasta_raw)), datetime.min.time(), dt_timezone.utc
            )
    except ValueError:
        raise _error_validacion() from None
    if desde > hasta:
        raise _error_validacion()

    from apps.comunidad.models import PublicacionComunidad
    from apps.habitosymetas.models import Habito
    from apps.seguimiento.models import RegistroHabito

    rango = {"creado_en__gte": desde, "creado_en__lt": hasta}
    return {
        "periodoDesde": desde.isoformat().replace("+00:00", "Z"),
        "periodoHasta": hasta.isoformat().replace("+00:00", "Z"),
        "usuariosRegistrados": Usuario.objects.filter(**rango).count(),
        "usuariosActivos": Usuario.objects.filter(estado="activo").count(),
        "habitosCreados": Habito.objects.filter(**rango).count(),
        "registrosCreados": RegistroHabito.objects.filter(**rango).count(),
        "publicaciones": PublicacionComunidad.objects.filter(
            eliminado_en__isnull=True, **rango
        ).count(),
    }


# ---------------------------------------------------------------------------
# Moderación (modelos de comunidad, rutas /v1/admin/moderacion)
# ---------------------------------------------------------------------------
def listar_reportes_moderacion(*, estado_raw, limit_raw, offset_raw):
    from apps.comunidad.models import ReporteComunidad

    limit, offset = _parse_paginacion(
        limit_raw, offset_raw, limit_default=50, limit_max=100
    )
    qs = ReporteComunidad.objects.all()
    if estado_raw not in (None, ""):
        if estado_raw not in ("pendiente", "resuelto", "descartado"):
            raise _error_validacion()
        qs = qs.filter(estado=estado_raw)
    return list(qs.order_by("creado_en")[offset:offset + limit])


def resolver_reporte_moderacion(admin, reporte_id_raw, *, resolucion, razon) -> None:
    from apps.comunidad.models import PublicacionComunidad, ReporteComunidad
    from apps.habitosymetas.services import parse_uuid

    error_404 = ContractError("reporte no encontrado", status_code=404, codigo="not_found")
    rid = parse_uuid(reporte_id_raw, error_404)

    if resolucion not in ("aprobar", "ocultar"):
        raise _error_validacion()
    if not isinstance(razon, str) or len(razon) > 500:
        raise _error_validacion()

    with transaction.atomic():
        reporte = (
            ReporteComunidad.objects.select_for_update().filter(id=rid).first()
        )
        if reporte is None:
            raise error_404
        if reporte.estado != "pendiente":
            # Quirk literal de Go: reutiliza ErrReporteDuplicado
            raise ContractError(
                "la publicacion ya fue reportada por este usuario",
                status_code=409, codigo="report_already_exists",
            )
        nuevo_estado, post_estado = ("resuelto", "oculto") if resolucion == "ocultar" \
            else ("descartado", "visible")
        reporte.estado = nuevo_estado
        reporte.resuelto_en = timezone.now()
        reporte.resuelto_por = admin
        reporte.save(update_fields=["estado", "resuelto_en", "resuelto_por"])
        PublicacionComunidad.objects.filter(id=reporte.publicacion_id).update(
            estado_moderacion=post_estado
        )
        _auditar(
            admin, reporte.publicacion.usuario,
            f"resolver_reporte_{resolucion}", razon,
        )


# ---------------------------------------------------------------------------
# Solicitudes de acceso administrador
# ---------------------------------------------------------------------------
def crear_solicitud(usuario, *, motivo) -> SolicitudAdministrativa:
    if not isinstance(motivo, str):
        raise _error_validacion()
    motivo_valido = motivo.strip()
    if not motivo_valido or len(motivo_valido) > 500:
        raise _error_validacion()

    actual = (
        SolicitudAdministrativa.objects.filter(usuario=usuario)
        .order_by("-creado_en")
        .first()
    )
    if actual is not None and actual.estado == "pendiente":
        raise ContractError(
            MENSAJE_SOLICITUD_CONFLICTO, status_code=409, codigo="request_conflict"
        )
    return SolicitudAdministrativa.objects.create(usuario=usuario, motivo=motivo_valido)


def obtener_solicitud_propia(usuario) -> SolicitudAdministrativa:
    solicitud = (
        SolicitudAdministrativa.objects.filter(usuario=usuario)
        .select_related("usuario")
        .order_by("-creado_en")
        .first()
    )
    if solicitud is None:
        raise ContractError(MENSAJE_SOLICITUD_404, status_code=404, codigo="not_found")
    return solicitud


def listar_solicitudes(*, estado_raw, limit_raw, offset_raw):
    limit, offset = _parse_paginacion(
        limit_raw, offset_raw, limit_default=50, limit_max=50
    )
    qs = SolicitudAdministrativa.objects.select_related("usuario")
    if estado_raw not in (None, ""):
        if estado_raw not in ("pendiente", "aprobada", "rechazada"):
            raise _error_validacion()
        qs = qs.filter(estado=estado_raw)
    return list(qs.order_by("-creado_en", "id")[offset:offset + limit])


def resolver_solicitud(admin, solicitud_id_raw, *, decision, razon) -> SolicitudAdministrativa:
    from apps.habitosymetas.services import parse_uuid

    error_404 = ContractError(MENSAJE_SOLICITUD_404, status_code=404, codigo="not_found")
    sid = parse_uuid(solicitud_id_raw, error_404)

    decision_valida = decision.strip().lower() if isinstance(decision, str) else ""
    if decision_valida not in ("aprobar", "rechazar"):
        raise _error_validacion()
    razon_valida = _validar_razon(razon)
    estado = "aprobada" if decision_valida == "aprobar" else "rechazada"

    with transaction.atomic():
        solicitud = (
            SolicitudAdministrativa.objects.select_for_update()
            .filter(id=sid)
            .first()
        )
        if solicitud is None:
            raise error_404
        if solicitud.estado != "pendiente":
            raise ContractError(
                MENSAJE_SOLICITUD_CONFLICTO, status_code=409, codigo="request_conflict"
            )
        if estado == "aprobada":
            Usuario.objects.filter(id=solicitud.usuario_id).update(rol="admin")
        ahora = timezone.now()
        solicitud.estado = estado
        solicitud.razon_decision = razon_valida
        solicitud.revisado_por = admin
        solicitud.revisado_en = ahora
        solicitud.save()
        accion = "aprobar_solicitud_admin" if estado == "aprobada" else "rechazar_solicitud_admin"
        _auditar(admin, solicitud.usuario, accion, razon_valida)
    solicitud.refresh_from_db()
    return solicitud
