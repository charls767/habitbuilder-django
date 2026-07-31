"""Casos de uso de 'hábitos y metas' (espejo de internal/habitosymetas).

Mensajes literales de Go (este módulo NO usa tildes: "invalido",
"validacion", "transicion"). Reglas de dominio replicadas:
  - nombre ≤120 runas; categoria recortada, no vacía, ≤50 runas.
  - frecuencia discriminada por tipo (dias 0-6 estilo time.Weekday).
  - hábitos eliminados: invisibles (404) en todo excepto DELETE (idempotente).
  - transiciones: pausar solo activo; reanudar solo pausado; completar es
    no-op sobre completado y 404 sobre eliminado (el repo lo filtra antes).
  - la propiedad cruzada nunca responde 403: siempre 404 indistinguible.
"""
import uuid as uuid_lib
from datetime import date, datetime

from django.db import transaction
from django.utils import timezone

from apps.plataforma.api.exceptions import ContractError

from .models import Habito, HabitoPausa, MetaPersonal

MENSAJE_VALIDACION = "la solicitud contiene errores de validacion"
MENSAJE_HABITO_NO_ENCONTRADO = "habito no encontrado"
MENSAJE_META_NO_ENCONTRADA = "meta no encontrada"
MENSAJE_TRANSICION = "transicion de estado invalida"

NOMBRE_MAX_RUNAS = 120
CATEGORIA_MAX_RUNAS = 50
PERIODOS_VALIDOS = {"semana", "mes"}
ESTADOS_META_VALIDOS = {"en_progreso", "lograda", "pausada", "cancelada"}


def _error_validacion() -> ContractError:
    return ContractError(MENSAJE_VALIDACION, status_code=400)


def _habito_404() -> ContractError:
    return ContractError(MENSAJE_HABITO_NO_ENCONTRADO, status_code=404)


def _meta_404() -> ContractError:
    return ContractError(MENSAJE_META_NO_ENCONTRADA, status_code=404)


def parse_uuid(raw, error: ContractError) -> uuid_lib.UUID:
    try:
        return uuid_lib.UUID(str(raw))
    except (ValueError, AttributeError, TypeError):
        raise error from None


def parse_fecha(raw, mensaje: str) -> date:
    """Espejo de parseFecha (layout 2006-01-02); cualquier fallo responde
    400 con el mensaje específico del handler Go."""
    try:
        return datetime.strptime(str(raw), "%Y-%m-%d").date()
    except (ValueError, TypeError):
        raise ContractError(mensaje, status_code=400) from None


# ---------------------------------------------------------------------------
# Validaciones de dominio
# ---------------------------------------------------------------------------
def _validar_nombre(nombre) -> str:
    if not isinstance(nombre, str) or not nombre or len(nombre) > NOMBRE_MAX_RUNAS:
        raise _error_validacion()
    return nombre


def _validar_categoria(categoria):
    """buildCategoria: None pasa; si viene, recortada, no vacía, ≤50 runas."""
    if categoria is None:
        return None
    if not isinstance(categoria, str):
        raise _error_validacion()
    recortada = categoria.strip()
    if not recortada or len(recortada) > CATEGORIA_MAX_RUNAS:
        raise _error_validacion()
    return recortada


def _validar_frecuencia(dto) -> dict:
    """buildFrecuencia: forma etiquetada por tipo. Devuelve los campos de
    columna (tipo, dias_semana, veces, periodo)."""
    if not isinstance(dto, dict):
        raise _error_validacion()
    tipo = dto.get("tipo")
    if tipo == "diaria":
        return {"frecuencia_tipo": "diaria", "frecuencia_dias_semana": None,
                "frecuencia_veces": None, "frecuencia_periodo": None}
    if tipo == "dias_especificos":
        dias = dto.get("diasSemana")
        if not isinstance(dias, list) or not dias:
            raise _error_validacion()
        for d in dias:
            if not isinstance(d, int) or isinstance(d, bool) or not 0 <= d <= 6:
                raise _error_validacion()
        return {"frecuencia_tipo": "dias_especificos", "frecuencia_dias_semana": dias,
                "frecuencia_veces": None, "frecuencia_periodo": None}
    if tipo == "n_veces_por_periodo":
        veces = dto.get("veces")
        periodo = dto.get("periodo")
        if not isinstance(veces, int) or isinstance(veces, bool) or veces < 1:
            raise _error_validacion()
        if periodo not in PERIODOS_VALIDOS:
            raise _error_validacion()
        return {"frecuencia_tipo": "n_veces_por_periodo", "frecuencia_dias_semana": None,
                "frecuencia_veces": veces, "frecuencia_periodo": periodo}
    raise _error_validacion()


def _validar_meta_id(raw):
    """buildMetaID: None pasa; UUID inválido es error de validación (400)."""
    if raw is None:
        return None
    return parse_uuid(raw, _error_validacion())


# ---------------------------------------------------------------------------
# Hábitos
# ---------------------------------------------------------------------------
def _habitos_de(usuario):
    return Habito.objects.filter(usuario=usuario, eliminado_en__isnull=True)


def obtener_habito(usuario, habito_id) -> Habito:
    hid = parse_uuid(habito_id, _habito_404())
    habito = _habitos_de(usuario).filter(id=hid).first()
    if habito is None:
        raise _habito_404()
    return habito


def listar_habitos(usuario):
    return list(_habitos_de(usuario).order_by("creado_en"))


def crear_habito(usuario, *, nombre, descripcion, fecha_inicio: date,
                 frecuencia, categoria, meta_id) -> Habito:
    campos = _validar_frecuencia(frecuencia)
    return Habito.objects.create(
        usuario=usuario,
        nombre=_validar_nombre(nombre),
        descripcion=descripcion,
        fecha_inicio=fecha_inicio,
        categoria=_validar_categoria(categoria),
        meta_id=_validar_meta_id(meta_id),
        **campos,
    )


def editar_habito(usuario, habito_id, cambios: dict) -> Habito:
    """Merge parcial: solo las claves presentes reemplazan el valor actual
    (espejo de EditarHabito.Ejecutar con campos puntero)."""
    habito = obtener_habito(usuario, habito_id)

    if "nombre" in cambios:
        habito.nombre = _validar_nombre(cambios["nombre"])
    if "descripcion" in cambios:
        habito.descripcion = cambios["descripcion"]
    if "frecuencia" in cambios:
        for campo, valor in _validar_frecuencia(cambios["frecuencia"]).items():
            setattr(habito, campo, valor)
    if "categoria" in cambios:
        habito.categoria = _validar_categoria(cambios["categoria"])
    if "metaId" in cambios:
        habito.meta_id = _validar_meta_id(cambios["metaId"])

    habito.save()
    return habito


def pausar_habito(usuario, habito_id, *, inicio: date, fin) -> Habito:
    habito = obtener_habito(usuario, habito_id)
    if habito.estado != Habito.Estado.ACTIVO:
        raise ContractError(MENSAJE_TRANSICION, status_code=400)
    if fin is not None and fin < inicio:
        raise _error_validacion()
    with transaction.atomic():
        HabitoPausa.objects.create(habito=habito, inicio=inicio, fin=fin)
        habito.estado = Habito.Estado.PAUSADO
        habito.save(update_fields=["estado"])
    return habito


def reanudar_habito(usuario, habito_id) -> Habito:
    habito = obtener_habito(usuario, habito_id)
    if habito.estado != Habito.Estado.PAUSADO:
        raise ContractError(MENSAJE_TRANSICION, status_code=400)
    pausa = habito.pausas.order_by("-creado_en").first()
    if pausa is None:
        raise ContractError(MENSAJE_TRANSICION, status_code=400)
    hoy = timezone.now().date()
    if hoy < pausa.inicio:  # conFin: fin no puede ser anterior a inicio
        raise _error_validacion()
    with transaction.atomic():
        pausa.fin = hoy
        pausa.save(update_fields=["fin"])
        habito.estado = Habito.Estado.ACTIVO
        habito.save(update_fields=["estado"])
    return habito


def completar_habito(usuario, habito_id) -> Habito:
    habito = obtener_habito(usuario, habito_id)
    if habito.estado == Habito.Estado.COMPLETADO:
        return habito  # idempotente
    if habito.estado not in (Habito.Estado.ACTIVO, Habito.Estado.PAUSADO):
        raise ContractError(MENSAJE_TRANSICION, status_code=400)
    habito.estado = Habito.Estado.COMPLETADO
    habito.save(update_fields=["estado"])
    return habito


def eliminar_habito(usuario, habito_id) -> tuple[Habito, dict]:
    """Soft-delete (HABIT-06): funciona aun estando eliminado (idempotente).
    Devuelve el impacto: conteos reales de recordatorios y registros."""
    hid = parse_uuid(habito_id, _habito_404())
    habito = Habito.objects.filter(usuario=usuario, id=hid).first()  # con eliminados
    if habito is None:
        raise _habito_404()

    from apps.recordatorios.models import Recordatorio
    from apps.seguimiento.models import RegistroHabito

    impacto = {
        "recordatoriosAfectados": Recordatorio.objects.filter(habito=habito).count(),
        "registrosAfectados": RegistroHabito.objects.filter(habito=habito).count(),
    }
    habito.estado = Habito.Estado.ELIMINADO
    if habito.eliminado_en is None:
        habito.eliminado_en = timezone.now()
    habito.save(update_fields=["estado", "eliminado_en"])
    return habito, impacto


# ---------------------------------------------------------------------------
# Metas
# ---------------------------------------------------------------------------
def obtener_meta(usuario, meta_id) -> MetaPersonal:
    mid = parse_uuid(meta_id, _meta_404())
    meta = MetaPersonal.objects.filter(usuario=usuario, id=mid).first()
    if meta is None:
        raise _meta_404()
    return meta


def listar_metas(usuario):
    return list(MetaPersonal.objects.filter(usuario=usuario).order_by("creado_en"))


def crear_meta(usuario, *, descripcion, fecha_objetivo: date) -> MetaPersonal:
    if not isinstance(descripcion, str) or not descripcion:
        raise _error_validacion()
    return MetaPersonal.objects.create(
        usuario=usuario, descripcion=descripcion, fecha_objetivo=fecha_objetivo
    )


def editar_meta(usuario, meta_id, *, descripcion=None, fecha_objetivo=None) -> MetaPersonal:
    meta = obtener_meta(usuario, meta_id)
    nueva_desc = descripcion if descripcion is not None else meta.descripcion
    nueva_fecha = fecha_objetivo if fecha_objetivo is not None else meta.fecha_objetivo
    if not isinstance(nueva_desc, str) or not nueva_desc:
        raise _error_validacion()
    meta.descripcion = nueva_desc
    meta.fecha_objetivo = nueva_fecha
    meta.save()
    return meta


def actualizar_estado_meta(usuario, meta_id, estado) -> MetaPersonal:
    """GOAL-03: el estado lo fija el caller, jamás se deriva de los hábitos."""
    meta = obtener_meta(usuario, meta_id)
    if estado not in ESTADOS_META_VALIDOS:
        raise _error_validacion()
    meta.estado = estado
    meta.save(update_fields=["estado"])
    return meta


def vincular_habitos(usuario, meta_id, habito_ids) -> MetaPersonal:
    meta = obtener_meta(usuario, meta_id)

    if not isinstance(habito_ids, list):
        raise _habito_404()
    ids: list[uuid_lib.UUID] = []
    vistos: set[uuid_lib.UUID] = set()
    for raw in habito_ids:
        hid = parse_uuid(raw, _habito_404())
        if hid in vistos:
            continue  # ids repetidos se colapsan
        vistos.add(hid)
        ids.append(hid)
    if not ids:
        raise _habito_404()

    propios = _habitos_de(usuario).filter(id__in=ids).count()
    if propios != len(ids):
        raise _habito_404()

    _habitos_de(usuario).filter(id__in=ids).update(meta=meta)
    return meta


def desvincular_habito(usuario, meta_id, habito_id) -> None:
    meta = obtener_meta(usuario, meta_id)
    hid = parse_uuid(habito_id, _habito_404())
    actualizados = _habitos_de(usuario).filter(id=hid, meta=meta).update(meta=None)
    if actualizados == 0:
        raise _habito_404()
