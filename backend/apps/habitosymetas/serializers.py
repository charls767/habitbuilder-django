"""Builders de respuesta de 'hábitos y metas' (espejo de dto.go).

HabitoResponse: descripcion/categoria/metaId son null EXPLÍCITO (punteros
sin omitempty en Go); en frecuencia, diasSemana/veces/periodo se OMITEN
cuando no aplican (omitempty).
"""
from .models import Habito, MetaPersonal


def _iso(dt) -> str:
    return dt.isoformat().replace("+00:00", "Z")


def frecuencia_dto(habito: Habito) -> dict:
    dto: dict = {"tipo": habito.frecuencia_tipo}
    if habito.frecuencia_dias_semana:
        dto["diasSemana"] = habito.frecuencia_dias_semana
    if habito.frecuencia_veces is not None:
        dto["veces"] = habito.frecuencia_veces
    if habito.frecuencia_periodo is not None:
        dto["periodo"] = habito.frecuencia_periodo
    return dto


def habito_response(habito: Habito) -> dict:
    return {
        "id": str(habito.id),
        "nombre": habito.nombre,
        "descripcion": habito.descripcion,
        "fechaInicio": habito.fecha_inicio.isoformat(),
        "frecuencia": frecuencia_dto(habito),
        "categoria": habito.categoria,
        "metaId": str(habito.meta_id) if habito.meta_id else None,
        "estado": habito.estado,
        "creadoEn": _iso(habito.creado_en),
    }


def meta_response(meta: MetaPersonal) -> dict:
    return {
        "id": str(meta.id),
        "descripcion": meta.descripcion,
        "fechaObjetivo": meta.fecha_objetivo.isoformat(),
        "estado": meta.estado,
        "creadoEn": _iso(meta.creado_en),
    }
