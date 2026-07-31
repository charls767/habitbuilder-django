"""Casos de uso de 'recordatorios' (espejo de internal/recordatorios).

Reglas replicadas de Go:
  - hora estricta "HH:mm" (5 chars, dos puntos en posición 2).
  - diasSemana ISO 1-7, entre 1 y 7 valores, sin repetidos, se ordenan.
  - mensaje recortado, 1..280 runas.
  - crear exige habito ACTIVO siempre (aunque activo=false) → 409
    habit_inactive_for_reminder si está pausado/completado.
  - editar solo exige habito activo al REACTIVAR (inactivo→activo); si el
    habito fue eliminado se trata como estado 'eliminado'.
  - orden de validación de Go preservado (hora→dias→habito→mensaje→estado).
  - asimetría literal de Go: en listar, un UUID malformado responde
    "habito no encontrado", pero un habito inexistente/ajeno responde
    "recordatorio no encontrado" (pasa por mapDomainError).
"""
import re
from datetime import time as time_of_day

from apps.habitosymetas.models import Habito
from apps.plataforma.api.exceptions import ContractError

from .models import Recordatorio

MENSAJE_MAX_RUNAS = 280
_HORA_RE = re.compile(r"^(?:[01][0-9]|2[0-3]):[0-5][0-9]$")

MENSAJE_RECORDATORIO_404 = "recordatorio no encontrado"
MENSAJE_HABITO_404 = "habito no encontrado"
MENSAJE_HABITO_INACTIVO = "el habito no esta activo para este recordatorio"
CODIGO_HABITO_INACTIVO = "habit_inactive_for_reminder"
MENSAJE_VALIDACION = "la solicitud contiene errores de validacion"
CODIGO_VALIDACION = "invalid_request"


def _rec_404() -> ContractError:
    return ContractError(MENSAJE_RECORDATORIO_404, status_code=404)


def _error_validacion() -> ContractError:
    return ContractError(MENSAJE_VALIDACION, status_code=400, codigo=CODIGO_VALIDACION)


def _conflicto_habito_inactivo() -> ContractError:
    return ContractError(
        MENSAJE_HABITO_INACTIVO, status_code=409, codigo=CODIGO_HABITO_INACTIVO
    )


def _parse_hora(raw) -> time_of_day:
    """ParseHoraLocal: exactamente HH:mm de 24 horas."""
    if not isinstance(raw, str) or not _HORA_RE.match(raw):
        raise _error_validacion()
    return time_of_day(int(raw[:2]), int(raw[3:]))


def _normalizar_dias(raw) -> list[int]:
    """NewDiasSemana: ISO 1-7, 1..7 valores, sin repetidos, ordenados."""
    if not isinstance(raw, list) or not 1 <= len(raw) <= 7:
        raise _error_validacion()
    vistos: set[int] = set()
    for d in raw:
        if not isinstance(d, int) or isinstance(d, bool) or not 1 <= d <= 7:
            raise _error_validacion()
        if d in vistos:
            raise _error_validacion()  # repetidos son error, no se colapsan
        vistos.add(d)
    return sorted(raw)


def _normalizar_mensaje(raw) -> str:
    if not isinstance(raw, str):
        raise _error_validacion()
    normalizado = raw.strip()
    if not normalizado or len(normalizado) > MENSAJE_MAX_RUNAS:
        raise _error_validacion()
    return normalizado


def _estado_de_habito(usuario, habito_id_uuid) -> str:
    """PgHabitoConsulta.EstadoDeHabito: filtra eliminado_en IS NULL; el
    habito inexistente/ajeno/eliminado responde como recordatorio 404."""
    estado = (
        Habito.objects.filter(
            id=habito_id_uuid, usuario=usuario, eliminado_en__isnull=True
        )
        .values_list("estado", flat=True)
        .first()
    )
    if estado is None:
        raise _rec_404()
    return estado


def listar_recordatorios(usuario, habito_id_raw) -> list[Recordatorio]:
    from apps.habitosymetas.services import parse_uuid

    hid = parse_uuid(
        habito_id_raw, ContractError(MENSAJE_HABITO_404, status_code=404)
    )
    _estado_de_habito(usuario, hid)  # existencia/propiedad
    return list(
        Recordatorio.objects.filter(usuario=usuario, habito_id=hid).order_by("creado_en")
    )


def crear_recordatorio(usuario, habito_id_raw, *, mensaje, hora, dias_semana, activo):
    from apps.habitosymetas.services import parse_uuid

    # ParseHabitoID falla → ErrHabitoNoEncontrado → mapper → recordatorio 404
    hid = parse_uuid(habito_id_raw, _rec_404())
    hora_valida = _parse_hora(hora)
    dias = _normalizar_dias(dias_semana)
    estado_habito = _estado_de_habito(usuario, hid)
    mensaje_norm = _normalizar_mensaje(mensaje)
    if not isinstance(activo, bool):
        raise _error_validacion()
    # Crear exige habito activo SIEMPRE (ValidarElegibilidadActivacion)
    if estado_habito != Habito.Estado.ACTIVO:
        raise _conflicto_habito_inactivo()

    return Recordatorio.objects.create(
        usuario=usuario,
        habito_id=hid,
        mensaje=mensaje_norm,
        hora=hora_valida,
        dias_semana=dias,
        activo=activo,
    )


def _obtener_recordatorio(usuario, rec_id_raw) -> Recordatorio:
    from apps.habitosymetas.services import parse_uuid

    rid = parse_uuid(rec_id_raw, _rec_404())
    rec = Recordatorio.objects.filter(usuario=usuario, id=rid).first()
    if rec is None:
        raise _rec_404()
    return rec


def editar_recordatorio(usuario, rec_id_raw, *, mensaje, hora, dias_semana, activo):
    rec = _obtener_recordatorio(usuario, rec_id_raw)
    hora_valida = _parse_hora(hora)
    dias = _normalizar_dias(dias_semana)

    # Habito eliminado/inexistente se degrada a estado 'eliminado' (Go).
    estado_habito = (
        Habito.objects.filter(
            id=rec.habito_id, usuario=usuario, eliminado_en__isnull=True
        )
        .values_list("estado", flat=True)
        .first()
    ) or Habito.Estado.ELIMINADO

    mensaje_norm = _normalizar_mensaje(mensaje)
    if not isinstance(activo, bool):
        raise _error_validacion()
    # Reactivar (inactivo → activo) exige habito activo
    if not rec.activo and activo and estado_habito != Habito.Estado.ACTIVO:
        raise _conflicto_habito_inactivo()

    rec.mensaje = mensaje_norm
    rec.hora = hora_valida
    rec.dias_semana = dias
    rec.activo = activo
    rec.save()
    return rec


def eliminar_recordatorio(usuario, rec_id_raw) -> None:
    rec = _obtener_recordatorio(usuario, rec_id_raw)
    rec.delete()
