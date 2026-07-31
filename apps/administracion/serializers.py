"""Builders de respuesta de 'administración' (espejo de los DTOs Go).

En SolicitudAdministrativaResponse, usuarioNombre/usuarioEmail/
razonDecision/revisadoEn llevan omitempty: se OMITEN cuando están vacíos.
"""


def _iso(dt) -> str:
    return dt.isoformat().replace("+00:00", "Z")


def usuario_admin_response(u) -> dict:
    return {
        "id": str(u.id),
        "nombre": u.nombre,
        "email": u.email,
        "rol": u.rol,
        "estado": u.estado,
    }


def reporte_moderacion_response(r) -> dict:
    body = {
        "id": str(r.id),
        "publicacionId": str(r.publicacion_id),
        "motivo": r.motivo,
        "estado": r.estado,
        "creadoEn": _iso(r.creado_en),
    }
    if r.detalle:
        body["detalle"] = r.detalle
    return body


def solicitud_response(s, *, recien_creada: bool = False) -> dict:
    body = {
        "id": str(s.id),
        "usuarioId": str(s.usuario_id),
        "motivo": s.motivo,
        "estado": s.estado,
        "creadoEn": _iso(s.creado_en),
        "actualizadoEn": _iso(s.actualizado_en),
    }
    # Paridad Go: el 201 de crear serializa el agregado en memoria (sin el
    # join a usuarios) → usuarioNombre/usuarioEmail se omiten al crear.
    if not recien_creada:
        if s.usuario.nombre:
            body["usuarioNombre"] = s.usuario.nombre
        if s.usuario.email:
            body["usuarioEmail"] = s.usuario.email
    if s.razon_decision:
        body["razonDecision"] = s.razon_decision
    if s.revisado_en is not None:
        body["revisadoEn"] = _iso(s.revisado_en)
    return body
