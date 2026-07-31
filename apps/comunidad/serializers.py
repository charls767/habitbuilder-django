"""Builders de respuesta de 'comunidad' (espejo de dto.go).

habitoId lleva omitempty (se OMITE si es null); los contadores y
'reaccionada' vienen anotados por services._con_contadores.
"""


def _iso(dt) -> str:
    return dt.isoformat().replace("+00:00", "Z")


def publicacion_response(p) -> dict:
    body = {
        "id": str(p.id),
        "autorNombre": p.usuario.nombre,
        "contenido": p.contenido,
        "creadoEn": _iso(p.creado_en),
        "actualizadoEn": _iso(p.actualizado_en),
        "reacciones": p.n_reacciones,
        "comentarios": p.n_comentarios,
        "reaccionada": p.reaccionada_por_mi,
    }
    if p.habito_id is not None:
        body["habitoId"] = str(p.habito_id)
    return body


def comentario_response(c, *, recien_creado: bool = False) -> dict:
    # Paridad Go: el 201 de crear serializa el agregado en memoria, que no
    # carga autorNombre → llega como "" (el listado sí lo trae del join).
    return {
        "id": str(c.id),
        "publicacionId": str(c.publicacion_id),
        "autorNombre": "" if recien_creado else c.usuario.nombre,
        "contenido": c.contenido,
        "creadoEn": _iso(c.creado_en),
    }


def reporte_response(r) -> dict:
    return {
        "id": str(r.id),
        "publicacionId": str(r.publicacion_id),
        "motivo": r.motivo,
        "estado": r.estado,
        "creadoEn": _iso(r.creado_en),
    }
