"""Builder de respuesta de 'seguimiento' (espejo de dto.go)."""
from .models import RegistroHabito


def _iso(dt) -> str:
    return dt.isoformat().replace("+00:00", "Z")


def registro_response(reg: RegistroHabito) -> dict:
    body = {
        "id": str(reg.id),
        "habitoId": str(reg.habito_id),
        "fechaLocal": reg.fecha_local.isoformat(),
        "creadoEn": _iso(reg.creado_en),
        "actualizadoEn": _iso(reg.actualizado_en),
        "estado": reg.estado,
    }
    if reg.nota is not None:  # omitempty: la nota null se OMITE
        body["nota"] = reg.nota
    return body
