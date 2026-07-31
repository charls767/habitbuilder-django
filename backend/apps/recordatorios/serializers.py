"""Builder de respuesta de 'recordatorios' (espejo de dto.go)."""
from .models import Recordatorio


def recordatorio_response(rec: Recordatorio) -> dict:
    return {
        "id": str(rec.id),
        "habitoId": str(rec.habito_id),
        "mensaje": rec.mensaje,
        "hora": rec.hora.strftime("%H:%M"),
        "diasSemana": rec.dias_semana,
        "activo": rec.activo,
    }
