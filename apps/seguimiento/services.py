"""Casos de uso de 'seguimiento' (espejo de internal/seguimiento).

  - Upsert idempotente por (habito, usuario, fechaLocal): creado→201,
    sobrescrito→200; deliberadamente sin 409.
  - Se puede registrar sin importar el estado del hábito (activo/pausado/
    completado); solo propiedad/existencia responde 404.
  - fechaLocal futura (contra "hoy" en la zona horaria del perfil) → 400.
  - nota recortada, ≤500 runas; el recálculo de racha nunca hace fallar el
    registro (hook no fatal).
"""
import logging
from datetime import date

from django.db import transaction
from django.utils import timezone

from apps.habitosymetas.models import Habito
from apps.plataforma.api.exceptions import ContractError
from apps.progreso.services import (
    CODIGO_VALIDACION,
    MENSAJE_HABITO_404,
    MENSAJE_VALIDACION,
    Frecuencia,
    calcular_racha,
    resolver_hoy_local,
)

from .models import RegistroHabito

logger = logging.getLogger(__name__)

NOTA_MAX_RUNAS = 500
MENSAJE_FECHA_PARAM = "parametro de fecha invalido"


def _error_validacion() -> ContractError:
    return ContractError(MENSAJE_VALIDACION, status_code=400, codigo=CODIGO_VALIDACION)


def _habito_404() -> ContractError:
    return ContractError(MENSAJE_HABITO_404, status_code=404)


def _habito_propio(usuario, habito_id_raw) -> Habito:
    from apps.habitosymetas.services import parse_uuid

    hid = parse_uuid(habito_id_raw, _habito_404())
    habito = Habito.objects.filter(
        id=hid, usuario=usuario, eliminado_en__isnull=True
    ).first()
    if habito is None:
        raise _habito_404()
    return habito


def _parse_fecha_local(raw) -> date:
    try:
        return date.fromisoformat(str(raw))
    except (ValueError, TypeError):
        raise _error_validacion() from None


def listar_registros(usuario, habito_id_raw, *, desde_raw=None, hasta_raw=None):
    habito = _habito_propio(usuario, habito_id_raw)
    qs = RegistroHabito.objects.filter(usuario=usuario, habito=habito)
    error_param = ContractError(
        MENSAJE_FECHA_PARAM, status_code=400, codigo=CODIGO_VALIDACION
    )
    if desde_raw not in (None, ""):
        try:
            qs = qs.filter(fecha_local__gte=date.fromisoformat(str(desde_raw)))
        except ValueError:
            raise error_param from None
    if hasta_raw not in (None, ""):
        try:
            qs = qs.filter(fecha_local__lte=date.fromisoformat(str(hasta_raw)))
        except ValueError:
            raise error_param from None
    return list(qs.order_by("fecha_local"))


def registrar_completitud(usuario, habito_id_raw, *, fecha_local_raw, estado, nota):
    """Devuelve (registro, creado). Orden de validación de Go preservado."""
    from apps.habitosymetas.services import parse_uuid

    hid = parse_uuid(habito_id_raw, _habito_404())
    fecha_local = _parse_fecha_local(fecha_local_raw)
    if estado not in ("hecho", "parcial", "omitido"):
        raise _error_validacion()

    habito = Habito.objects.filter(
        id=hid, usuario=usuario, eliminado_en__isnull=True
    ).first()
    if habito is None:
        raise _habito_404()

    hoy_local = resolver_hoy_local(usuario)  # 404 'perfil no encontrado' si falta

    nota_norm = None
    if nota is not None:
        if not isinstance(nota, str):
            raise _error_validacion()
        nota_norm = nota.strip()
        if len(nota_norm) > NOTA_MAX_RUNAS:
            raise _error_validacion()

    if fecha_local > hoy_local:
        raise _error_validacion()  # ErrFechaFutura

    with transaction.atomic():
        registro, creado = RegistroHabito.objects.update_or_create(
            habito=habito,
            usuario=usuario,
            fecha_local=fecha_local,
            defaults={"estado": estado, "nota": nota_norm},
        )

    try:
        recalcular_racha(usuario, habito, hoy_local)
    except Exception:  # noqa: BLE001 - el hook jamás hace fallar el registro
        logger.warning("fallo recalculando racha de %s", habito.id, exc_info=True)

    return registro, creado


def recalcular_racha(usuario, habito: Habito, hoy_local: date) -> None:
    """RecalculadorRachaReal: persiste rachas_habito con la racha del
    historial completo del hábito (sin pausas, como en Go/seguimiento)."""
    from apps.progreso.models import RachaHabito

    registros = list(
        RegistroHabito.objects.filter(usuario=usuario, habito=habito)
        .order_by("fecha_local")
        .values_list("fecha_local", "estado")
    )
    frec = Frecuencia(
        tipo=habito.frecuencia_tipo,
        dias_semana=tuple(habito.frecuencia_dias_semana or ()),
        veces=habito.frecuencia_veces or 0,
        periodo=habito.frecuencia_periodo or "",
    )
    actual, mas_larga = calcular_racha(frec, habito.fecha_inicio, registros, hoy_local)
    RachaHabito.objects.update_or_create(
        habito=habito, usuario=usuario,
        defaults={
            "racha_actual": actual,
            "racha_mas_larga": max(mas_larga, actual),
            "actualizado_en": timezone.now(),
        },
    )
