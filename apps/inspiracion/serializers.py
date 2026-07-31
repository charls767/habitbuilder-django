"""Builder de respuesta de 'inspiración' (espejo de dto.go).

imagenUrl lleva omitempty: se OMITE cuando no hay imagen.
"""
from .models import ContenidoInspiracion


def _iso(dt) -> str:
    return dt.isoformat().replace("+00:00", "Z")


def contenido_response(c: ContenidoInspiracion) -> dict:
    body = {
        "id": str(c.id),
        "tipo": c.tipo,
        "titulo": c.titulo,
        "resumen": c.resumen,
        "url": c.url,
        "autor": c.autor,
        "destacado": c.destacado,
        "creadoEn": _iso(c.creado_en),
        "actualizadoEn": _iso(c.actualizado_en),
    }
    if c.imagen_url:
        body["imagenUrl"] = c.imagen_url
    return body
