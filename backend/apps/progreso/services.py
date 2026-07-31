"""Cálculo de progreso, rachas y estadísticas (espejo de internal/progreso
y del cálculo de racha de internal/seguimiento).

Convenciones heredadas de Go:
  - dias de semana de hábitos usan time.Weekday (domingo=0..sábado=6);
    en Python: go_weekday = (date.weekday() + 1) % 7.
  - clave de periodo semana = ISO "YYYY-Www"; mes = "YYYY-MM".
  - la racha de seguimiento IGNORA pausas; la de progreso las descuenta.
  - "hoy local" se resuelve con la zona horaria del perfil (fallback UTC).
"""
import zoneinfo
from dataclasses import dataclass
from datetime import date, timedelta

from django.utils import timezone

from apps.plataforma.api.exceptions import ContractError

MENSAJE_HABITO_404 = "habito no encontrado"
MENSAJE_PERFIL_404 = "perfil no encontrado"
MENSAJE_VALIDACION = "la solicitud contiene errores de validacion"
CODIGO_VALIDACION = "invalid_request"


@dataclass(frozen=True)
class Frecuencia:
    tipo: str
    dias_semana: tuple[int, ...] = ()
    veces: int = 0
    periodo: str = ""


@dataclass(frozen=True)
class Pausa:
    inicio: date
    fin: date | None

    def contiene(self, d: date) -> bool:
        if d < self.inicio:
            return False
        return self.fin is None or d <= self.fin


def _error_validacion() -> ContractError:
    return ContractError(MENSAJE_VALIDACION, status_code=400, codigo=CODIGO_VALIDACION)


def parse_periodo(raw) -> str:
    """periodoDesdeQuery: ausente → semana; fuera del enum → 400."""
    if raw in (None, ""):
        return "semana"
    if raw not in ("semana", "mes"):
        raise _error_validacion()
    return raw


def resolver_hoy_local(usuario) -> date:
    """resolverHoyLocal: hoy en la zona horaria del perfil; perfil ausente
    → 404 'perfil no encontrado'; zona ilegible → fallback UTC."""
    from apps.identidad.models import Perfil

    zona = (
        Perfil.objects.filter(usuario=usuario)
        .values_list("zona_horaria", flat=True)
        .first()
    )
    if zona is None:
        raise ContractError(MENSAJE_PERFIL_404, status_code=404)
    try:
        tz = zoneinfo.ZoneInfo(zona)
    except (zoneinfo.ZoneInfoNotFoundError, ValueError):
        tz = zoneinfo.ZoneInfo("UTC")
    return timezone.now().astimezone(tz).date()


def _go_weekday(d: date) -> int:
    return (d.weekday() + 1) % 7  # Python lun=0 → Go dom=0


def _dias_en_rango(desde: date, hasta: date):
    d = desde
    while d <= hasta:
        yield d
        d += timedelta(days=1)


def _clave_de_periodo(periodo: str, d: date) -> str:
    if periodo == "mes":
        return f"{d.year:04d}-{d.month:02d}"
    iso = d.isocalendar()
    return f"{iso.year:04d}-W{iso.week:02d}"


def _claves_ordenadas(periodo: str, desde: date, hasta: date,
                      pausas: list[Pausa] | None = None) -> list[str]:
    claves: list[str] = []
    ultima = None
    for d in _dias_en_rango(desde, hasta):
        if pausas and any(p.contiene(d) for p in pausas):
            continue
        k = _clave_de_periodo(periodo, d)
        if k != ultima:
            claves.append(k)
            ultima = k
    return claves


def _racha_desde_unidades(completadas: list[bool], ultima_es_actual: bool) -> tuple[int, int]:
    corrida = 0
    mas_larga = 0
    for c in completadas:
        if c:
            corrida += 1
            mas_larga = max(mas_larga, corrida)
        else:
            corrida = 0
    fin = len(completadas)
    if ultima_es_actual and fin > 0 and not completadas[-1]:
        fin -= 1  # la unidad actual abierta aún puede completarse
    actual = 0
    for i in range(fin - 1, -1, -1):
        if not completadas[i]:
            break
        actual += 1
    return actual, mas_larga


def rango_de_periodo(periodo: str, ancla: date) -> tuple[date, date]:
    if periodo == "mes":
        primero = ancla.replace(day=1)
        if primero.month == 12:
            ultimo = primero.replace(year=primero.year + 1, month=1) - timedelta(days=1)
        else:
            ultimo = primero.replace(month=primero.month + 1) - timedelta(days=1)
        return primero, ultimo
    lunes = ancla - timedelta(days=ancla.isoweekday() - 1)
    return lunes, lunes + timedelta(days=6)


def calcular_racha(frec: Frecuencia, fecha_inicio: date,
                   registros: list[tuple[date, str]], hoy: date,
                   pausas: list[Pausa] | None = None) -> tuple[int, int]:
    """CalcularRacha (seguimiento, pausas=None) / núcleo de racha de
    CalcularProgreso (progreso, con pausas)."""
    if frec.tipo == "n_veces_por_periodo":
        conteo: dict[str, int] = {}
        for f, estado in registros:
            if estado != "hecho":
                continue
            if pausas and any(p.contiene(f) for p in pausas):
                continue
            k = _clave_de_periodo(frec.periodo, f)
            conteo[k] = conteo.get(k, 0) + 1
        claves = _claves_ordenadas(frec.periodo, fecha_inicio, hoy, pausas)
        satisfechas = [conteo.get(k, 0) >= frec.veces for k in claves]
        if pausas is not None:
            clave_hoy = _clave_de_periodo(frec.periodo, hoy)
            ultima_actual = bool(claves) and claves[-1] == clave_hoy
        else:
            ultima_actual = bool(claves)
        return _racha_desde_unidades(satisfechas, ultima_actual)

    completados = {f for f, estado in registros if estado == "hecho"}
    dias: list[date] = []
    if fecha_inicio <= hoy:
        for d in _dias_en_rango(fecha_inicio, hoy):
            if frec.tipo == "dias_especificos" and _go_weekday(d) not in frec.dias_semana:
                continue
            if pausas and any(p.contiene(d) for p in pausas):
                continue
            dias.append(d)
    completadas = [d in completados for d in dias]
    ultima_es_hoy = bool(dias) and dias[-1] == hoy
    return _racha_desde_unidades(completadas, ultima_es_hoy)


def calcular_progreso(frec: Frecuencia, fecha_inicio: date,
                      registros: list[tuple[date, str]], pausas: list[Pausa],
                      periodo: str, ancla: date, hoy: date) -> dict:
    """CalcularProgreso: rachas globales + porcentaje sobre la ventana del
    periodo, con estado sin_datos si no hay ocurrencias o registros."""
    periodo_desde, periodo_hasta = rango_de_periodo(periodo, ancla)
    actual, mas_larga = calcular_racha(frec, fecha_inicio, registros, hoy, pausas)

    ventana_desde = max(fecha_inicio, periodo_desde)
    ventana_hasta = min(hoy, periodo_hasta)
    numerador = denominador = 0
    if ventana_desde <= ventana_hasta:
        if frec.tipo == "n_veces_por_periodo":
            conteo: dict[str, int] = {}
            for f, estado in registros:
                if estado != "hecho" or any(p.contiene(f) for p in pausas):
                    continue
                k = _clave_de_periodo(frec.periodo, f)
                conteo[k] = conteo.get(k, 0) + 1
            for k in _claves_ordenadas(frec.periodo, ventana_desde, ventana_hasta, pausas):
                numerador += min(conteo.get(k, 0), frec.veces)  # clamp ≤100%
                denominador += frec.veces
        else:
            completados = {f for f, estado in registros if estado == "hecho"}
            for d in _dias_en_rango(ventana_desde, ventana_hasta):
                if frec.tipo == "dias_especificos" and _go_weekday(d) not in frec.dias_semana:
                    continue
                if any(p.contiene(d) for p in pausas):
                    continue
                denominador += 1
                if d in completados:
                    numerador += 1

    sin_datos = denominador == 0 or len(registros) == 0
    return {
        "periodoDesde": periodo_desde.isoformat(),
        "periodoHasta": periodo_hasta.isoformat(),
        "rachaActual": actual,
        "rachaMasLarga": mas_larga,
        "porcentaje": 0 if sin_datos else (numerador / denominador) * 100,
        "estado": "sin_datos" if sin_datos else "con_datos",
    }


# ---------------------------------------------------------------------------
# Acceso a datos de hábitos (adaptadores de consulta)
# ---------------------------------------------------------------------------
def _frecuencia_de(habito) -> Frecuencia:
    return Frecuencia(
        tipo=habito.frecuencia_tipo,
        dias_semana=tuple(habito.frecuencia_dias_semana or ()),
        veces=habito.frecuencia_veces or 0,
        periodo=habito.frecuencia_periodo or "",
    )


def _registros_de(usuario, habito_id) -> list[tuple[date, str]]:
    from apps.seguimiento.models import RegistroHabito

    return list(
        RegistroHabito.objects.filter(usuario=usuario, habito_id=habito_id)
        .order_by("fecha_local")
        .values_list("fecha_local", "estado")
    )


def _pausas_de(habito) -> list[Pausa]:
    return [Pausa(inicio=p.inicio, fin=p.fin) for p in habito.pausas.all()]


def _resolver_ancla(fecha_raw, hoy: date) -> date:
    if fecha_raw in (None, ""):
        return hoy
    try:
        return date.fromisoformat(str(fecha_raw))
    except ValueError:
        raise _error_validacion() from None


def ver_progreso_habito(usuario, habito_id_raw, *, periodo_raw, fecha_raw) -> dict:
    from apps.habitosymetas.models import Habito
    from apps.habitosymetas.services import parse_uuid

    hid = parse_uuid(habito_id_raw, ContractError(MENSAJE_HABITO_404, status_code=404))
    periodo = parse_periodo(periodo_raw)
    habito = Habito.objects.filter(
        id=hid, usuario=usuario, eliminado_en__isnull=True
    ).first()
    if habito is None:
        raise ContractError(MENSAJE_HABITO_404, status_code=404)
    hoy = resolver_hoy_local(usuario)
    ancla = _resolver_ancla(fecha_raw, hoy)
    progreso = calcular_progreso(
        _frecuencia_de(habito), habito.fecha_inicio,
        _registros_de(usuario, habito.id), _pausas_de(habito),
        periodo, ancla, hoy,
    )
    return {"habitoId": str(habito.id), **progreso}


def ver_progreso_lista(usuario, *, periodo_raw, fecha_raw) -> list[dict]:
    from apps.habitosymetas.models import Habito

    periodo = parse_periodo(periodo_raw)
    hoy = resolver_hoy_local(usuario)
    ancla = _resolver_ancla(fecha_raw, hoy)
    resultado = []
    for habito in Habito.objects.filter(
        usuario=usuario, eliminado_en__isnull=True
    ).order_by("creado_en"):
        progreso = calcular_progreso(
            _frecuencia_de(habito), habito.fecha_inicio,
            _registros_de(usuario, habito.id), _pausas_de(habito),
            periodo, ancla, hoy,
        )
        resultado.append({"habitoId": str(habito.id), **progreso})
    return resultado


def ver_estadisticas(usuario, *, periodo_raw, fecha_raw, habito_id_raw, categoria) -> dict:
    """STATS-03: incluye hábitos completados y ELIMINADOS (solo filtra
    propiedad); habitoId no propio → 404; propio pero excluido por
    categoria → 200 insuficiente."""
    from apps.habitosymetas.models import Habito
    from apps.habitosymetas.services import parse_uuid

    periodo = parse_periodo(periodo_raw)
    hoy = resolver_hoy_local(usuario)
    ancla = _resolver_ancla(fecha_raw, hoy)
    periodo_desde, periodo_hasta = rango_de_periodo(periodo, ancla)

    habitos = Habito.objects.filter(usuario=usuario)  # sin filtro eliminado_en
    hid = None
    if habito_id_raw not in (None, ""):
        hid = parse_uuid(habito_id_raw, _error_validacion())
        habitos = habitos.filter(id=hid)
    if categoria not in (None, ""):
        habitos = habitos.filter(categoria=categoria)
    habitos = list(habitos.order_by("creado_en"))

    if not habitos and hid is not None:
        # WR-02: decidir 404 vs vacío re-verificando propiedad sin categoria
        if not Habito.objects.filter(usuario=usuario, id=hid).exists():
            raise ContractError(MENSAJE_HABITO_404, status_code=404)

    per_habito = []
    for habito in habitos:
        registros = _registros_de(usuario, habito.id)
        progreso = calcular_progreso(
            _frecuencia_de(habito), habito.fecha_inicio, registros,
            _pausas_de(habito), periodo, ancla, hoy,
        )
        total_hecho = sum(
            1 for f, e in registros
            if periodo_desde <= f <= periodo_hasta and e == "hecho"
        )
        total_omitido = sum(
            1 for f, e in registros
            if periodo_desde <= f <= periodo_hasta and e == "omitido"
        )
        per_habito.append({
            "habitoId": str(habito.id),
            "nombre": habito.nombre,
            "porcentaje": progreso["porcentaje"],
            "rachaMasLarga": progreso["rachaMasLarga"],
            "totalHecho": total_hecho,
            "totalOmitido": total_omitido,
        })

    # GenerarInformeEstadisticas
    mejor_racha = max((e["rachaMasLarga"] for e in per_habito), default=0)
    con_datos = [e for e in per_habito if e["totalHecho"] + e["totalOmitido"] > 0]
    porcentaje = (
        sum(e["porcentaje"] for e in con_datos) / len(con_datos) if con_datos else 0
    )
    mas_consistentes = sorted(
        per_habito,
        key=lambda e: (-e["porcentaje"], e["nombre"], e["habitoId"]),
    )
    mas_omitidos = sorted(
        per_habito,
        key=lambda e: (-e["totalOmitido"], e["nombre"], e["habitoId"]),
    )
    return {
        "periodoDesde": periodo_desde.isoformat(),
        "periodoHasta": periodo_hasta.isoformat(),
        "porcentaje": porcentaje,
        "mejorRacha": mejor_racha,
        "masConsistentes": mas_consistentes,
        "masOmitidos": mas_omitidos,
        "estado": "con_datos" if per_habito and con_datos else "insuficiente",
    }
