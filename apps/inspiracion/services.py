"""Casos de uso del catálogo público de 'inspiración' (espejo de
internal/inspiracion, rutas no-admin).

  - Solo contenido publicado; orden: destacado DESC, creado_en DESC.
  - Filtro tipo fuera del enum → 400 validacion; paginación 1..50/≥0.
"""
from apps.plataforma.api.exceptions import ContractError

from .models import ContenidoInspiracion

TIPOS_VALIDOS = {"articulo", "video", "audio"}
MENSAJE_VALIDACION = "la solicitud contiene errores de validacion"
MENSAJE_CONTENIDO_404 = "contenido no encontrado"


def _error_validacion() -> ContractError:
    return ContractError(MENSAJE_VALIDACION, status_code=400, codigo="invalid_request")


def _publicados():
    return ContenidoInspiracion.objects.filter(publicado=True).order_by(
        "-destacado", "-creado_en"
    )


def listar_contenidos(*, tipo_raw, limit_raw, offset_raw):
    tipo = None
    if tipo_raw not in (None, ""):
        if tipo_raw not in TIPOS_VALIDOS:
            raise _error_validacion()
        tipo = tipo_raw
    try:
        limit = int(limit_raw) if limit_raw not in (None, "") else 20
        offset = int(offset_raw) if offset_raw not in (None, "") else 0
    except (TypeError, ValueError):
        raise _error_validacion() from None
    if limit < 1 or limit > 50 or offset < 0:
        raise _error_validacion()

    qs = _publicados()
    if tipo:
        qs = qs.filter(tipo=tipo)
    return list(qs[offset:offset + limit])


def obtener_contenido(contenido_id_raw) -> ContenidoInspiracion:
    from apps.habitosymetas.services import parse_uuid

    error = ContractError(MENSAJE_CONTENIDO_404, status_code=404, codigo="not_found")
    cid = parse_uuid(contenido_id_raw, error)
    contenido = _publicados().filter(id=cid).first()
    if contenido is None:
        raise error
    return contenido


# ---------------------------------------------------------------------------
# Catálogo administrable (espejo de application/admin.go; rutas /v1/admin)
# ---------------------------------------------------------------------------
def _parse_bool_opcional(raw):
    if raw in (None, ""):
        return None
    if raw in ("true", "True", True):
        return True
    if raw in ("false", "False", False):
        return False
    raise _error_validacion()


def _contenido_404() -> ContractError:
    return ContractError(MENSAJE_CONTENIDO_404, status_code=404, codigo="not_found")


def _validar_campos_admin(*, tipo, titulo, resumen, url, imagen_url, autor) -> dict:
    """NewContenidoAdmin: tipo en enum; textos recortados con límites."""
    if tipo not in TIPOS_VALIDOS:
        raise _error_validacion()
    campos = {}
    for nombre, valor, maximo in (
        ("titulo", titulo, 180), ("resumen", resumen, 500),
        ("url", url, 2048), ("autor", autor, 180),
    ):
        if not isinstance(valor, str):
            raise _error_validacion()
        recortado = valor.strip()
        if not recortado or len(recortado) > maximo:
            raise _error_validacion()
        campos[nombre] = recortado
    if imagen_url is not None and not isinstance(imagen_url, str):
        raise _error_validacion()
    campos["imagen_url"] = (imagen_url or "").strip() or None
    campos["tipo"] = tipo
    return campos


def listar_contenidos_admin(*, tipo_raw, publicado_raw, destacado_raw, buscar_raw,
                            limit_raw, offset_raw):
    tipo = None
    if tipo_raw not in (None, ""):
        if tipo_raw not in TIPOS_VALIDOS:
            raise _error_validacion()
        tipo = tipo_raw
    publicado = _parse_bool_opcional(publicado_raw)
    destacado = _parse_bool_opcional(destacado_raw)
    try:
        limit = int(limit_raw) if limit_raw not in (None, "") else 50
        offset = int(offset_raw) if offset_raw not in (None, "") else 0
    except (TypeError, ValueError):
        raise _error_validacion() from None
    if limit < 1 or limit > 50 or offset < 0:
        raise _error_validacion()

    qs = ContenidoInspiracion.objects.order_by("-destacado", "-creado_en")
    if tipo:
        qs = qs.filter(tipo=tipo)
    if publicado is not None:
        qs = qs.filter(publicado=publicado)
    if destacado is not None:
        qs = qs.filter(destacado=destacado)
    buscar = (buscar_raw or "").strip()
    if buscar:
        from django.db.models import Q

        qs = qs.filter(Q(titulo__icontains=buscar) | Q(autor__icontains=buscar))
    return list(qs[offset:offset + limit])


def obtener_contenido_admin(contenido_id_raw) -> ContenidoInspiracion:
    from apps.habitosymetas.services import parse_uuid

    cid = parse_uuid(contenido_id_raw, _contenido_404())
    contenido = ContenidoInspiracion.objects.filter(id=cid).first()
    if contenido is None:
        raise _contenido_404()
    return contenido


def crear_contenido_admin(datos: dict) -> ContenidoInspiracion:
    """Campos requeridos: tipo/titulo/resumen/url/autor; defaults de Go:
    destacado=false, publicado=TRUE."""
    for requerido in ("tipo", "titulo", "resumen", "url", "autor"):
        if requerido not in datos:
            raise _error_validacion()
    campos = _validar_campos_admin(
        tipo=datos.get("tipo"), titulo=datos.get("titulo"),
        resumen=datos.get("resumen"), url=datos.get("url"),
        imagen_url=datos.get("imagenUrl"), autor=datos.get("autor"),
    )
    return ContenidoInspiracion.objects.create(
        destacado=bool(datos.get("destacado", False)),
        publicado=bool(datos.get("publicado", True)),
        **campos,
    )


def actualizar_contenido_admin(contenido_id_raw, datos: dict) -> ContenidoInspiracion:
    """Merge parcial campo a campo sobre el contenido actual (handler Go)."""
    contenido = obtener_contenido_admin(contenido_id_raw)
    campos = _validar_campos_admin(
        tipo=datos.get("tipo", contenido.tipo),
        titulo=datos.get("titulo", contenido.titulo),
        resumen=datos.get("resumen", contenido.resumen),
        url=datos.get("url", contenido.url),
        imagen_url=datos.get("imagenUrl", contenido.imagen_url),
        autor=datos.get("autor", contenido.autor),
    )
    for campo, valor in campos.items():
        setattr(contenido, campo, valor)
    if "destacado" in datos:
        contenido.destacado = bool(datos["destacado"])
    if "publicado" in datos:
        contenido.publicado = bool(datos["publicado"])
    contenido.save()
    return contenido


def eliminar_contenido_admin(contenido_id_raw) -> None:
    obtener_contenido_admin(contenido_id_raw).delete()
