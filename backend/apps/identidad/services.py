"""Casos de uso del dominio 'identidad' (espejo de internal/identidad/application).

Cada función replica un caso de uso Go, incluidos sus mensajes de error
literales, códigos de estado y garantías de seguridad:
  - AUTH-02: la validación de registro reporta TODOS los campos a la vez.
  - AUTH-05: el login verifica SIEMPRE contra un hash (dummy si el email no
    existe) para no filtrar existencia de cuentas por timing.
  - AUTH-06: el estado suspendido se comprueba solo tras verificar credenciales.
  - T-04-01/02: reset silencioso ante email desconocido; solo se persiste el
    sha256 del token (32 bytes de entropía, TTL 30 min).
"""
import hashlib
import logging
import re
import secrets
import zoneinfo
from dataclasses import dataclass
from datetime import datetime, timedelta
from datetime import timezone as dt_timezone
from functools import lru_cache

from django.contrib.auth.hashers import make_password
from django.db import IntegrityError, transaction
from django.utils import timezone
from rest_framework_simplejwt.tokens import AccessToken

from apps.plataforma.api.exceptions import ContractError

from .models import PasswordResetToken, Perfil, Usuario

logger = logging.getLogger(__name__)

CONSENTIMIENTO_VERSION_ACTUAL = "v1"
PASSWORD_MIN_LENGTH = 8
RESET_TOKEN_TTL = timedelta(minutes=30)
RESET_TOKEN_RAW_BYTES = 32

_EMAIL_RE = re.compile(r"^[^\s@]+@[^\s@]+\.[^\s@]+$")

MENSAJE_ERRORES_VALIDACION = "la solicitud contiene errores de validación"
MENSAJE_CREDENCIALES_INVALIDAS = "correo electrónico o contraseña inválidos"
MENSAJE_CUENTA_SUSPENDIDA = "la cuenta está suspendida"
MENSAJE_RESET_INVALIDO = "token inválido, expirado, o contraseña inválida"
MENSAJE_ZONA_HORARIA = "zona horaria inválida"
MENSAJE_ACCESIBILIDAD = "preferencia de accesibilidad inválida"

TAMANOS_TEXTO_VALIDOS = {"normal", "grande", "extra_grande"}


def _normalizar_email(raw: str) -> str:
    return raw.strip().lower()


def _email_valido(normalizado: str) -> bool:
    return bool(normalizado) and bool(_EMAIL_RE.match(normalizado))


def _password_fuerte(raw: str) -> bool:
    # Go cuenta runas (code points); len() sobre str en Python es equivalente.
    return bool(raw) and len(raw) >= PASSWORD_MIN_LENGTH


# ---------------------------------------------------------------------------
# CU-001 Registro
# ---------------------------------------------------------------------------
def registrar_usuario(
    *, nombre: str, email: str, password: str, terminos_aceptados: bool
) -> Usuario:
    """Valida TODOS los campos a la vez (AUTH-02) y crea Usuario + Perfil
    inicial en una transacción, como RegistrarUsuario.Ejecutar en Go."""
    campos: dict[str, str] = {}

    if not nombre:
        campos["nombre"] = "el nombre es obligatorio"

    email_norm = _normalizar_email(email)
    if not _email_valido(email_norm):
        campos["email"] = "el correo electrónico no es válido"

    if not _password_fuerte(password):
        campos["password"] = "la contraseña no cumple la fortaleza mínima"  # noqa: S105

    if not terminos_aceptados:
        campos["terminos"] = "debe aceptar los términos y la política de privacidad"

    # Pre-chequeo amable; el índice único lower(email) sigue siendo la
    # fuente de verdad (se re-verifica abajo vía IntegrityError).
    if "email" not in campos and Usuario.objects.filter(email=email_norm).exists():
        campos["email"] = "el correo electrónico ya está registrado"

    if campos:
        raise ContractError(MENSAJE_ERRORES_VALIDACION, status_code=422, errores=campos)

    try:
        with transaction.atomic():
            usuario = Usuario(
                nombre=nombre,
                email=email_norm,
                consentimiento_aceptado_en=timezone.now(),
                consentimiento_version=CONSENTIMIENTO_VERSION_ACTUAL,
            )
            usuario.set_password(password)
            usuario.save()
            Perfil.objects.create(usuario=usuario)  # defaults = NewPerfilInicial
    except IntegrityError:
        # Carrera perdida contra un registro concurrente del mismo email.
        raise ContractError(
            MENSAJE_ERRORES_VALIDACION,
            status_code=422,
            errores={"email": "el correo electrónico ya está registrado"},
        ) from None

    return usuario


# ---------------------------------------------------------------------------
# CU-002 Login
# ---------------------------------------------------------------------------
@dataclass(frozen=True)
class Sesion:
    token: str
    expira_en: datetime


@lru_cache(maxsize=1)
def _dummy_hash() -> str:
    """Hash precomputado contra el que se verifica cuando el email no existe,
    para que el camino not-found tarde lo mismo que el de contraseña
    incorrecta (AUTH-05, espejo de Argon2Hasher.DummyHash)."""
    return make_password("dummy-password-for-constant-time-verify")


def iniciar_sesion(*, email: str, password: str) -> Sesion:
    email_norm = _normalizar_email(email)
    usuario = None
    if _email_valido(email_norm):
        usuario = Usuario.objects.filter(email=email_norm).first()

    if usuario is not None:
        ok = usuario.check_password(password)
    else:
        # SIEMPRE se verifica contra un hash, exista o no la cuenta.
        from django.contrib.auth.hashers import check_password as _check

        _check(password, _dummy_hash())
        ok = False

    if not ok:
        raise ContractError(MENSAJE_CREDENCIALES_INVALIDAS, status_code=401)

    # Solo tras verificar credenciales (AUTH-06):
    if usuario.estado == Usuario.Estado.SUSPENDIDO:
        raise ContractError(MENSAJE_CUENTA_SUSPENDIDA, status_code=403)

    token = AccessToken.for_user(usuario)
    expira_en = datetime.fromtimestamp(token["exp"], tz=dt_timezone.utc)
    return Sesion(token=str(token), expira_en=expira_en)


# ---------------------------------------------------------------------------
# CU-003 Reset de contraseña
# ---------------------------------------------------------------------------
def _hash_reset_token(raw: str) -> str:
    return hashlib.sha256(raw.encode()).hexdigest()


def solicitar_reset(*, email: str) -> None:
    """Siempre termina en silencio (200) — nunca revela si el email existe
    (T-04-01). Espejo de SolicitarReset.Ejecutar."""
    email_norm = _normalizar_email(email)
    if not _email_valido(email_norm):
        return

    usuario = Usuario.objects.filter(email=email_norm).first()
    if usuario is None:
        return

    raw_token = secrets.token_urlsafe(RESET_TOKEN_RAW_BYTES)
    try:
        # atomic() interno: si el índice parcial rechaza el insert, solo se
        # revierte este savepoint y la transacción exterior sigue utilizable.
        with transaction.atomic():
            PasswordResetToken.objects.create(
                usuario=usuario,
                token_hash=_hash_reset_token(raw_token),
                expires_at=timezone.now() + RESET_TOKEN_TTL,
            )
    except IntegrityError:
        # Ya hay un token activo (índice parcial): el de la otra solicitud
        # es el que vale. Éxito genérico igualmente.
        return

    # Paridad con LogEmailSender: el enlace se registra en el log; el envío
    # real de correo queda fuera del alcance (igual que en Go).
    logger.info("enlace de reset generado para usuario %s", usuario.id)


def confirmar_reset(*, token: str, nueva_password: str) -> None:
    """Token inválido, usado, expirado o contraseña débil responden el MISMO
    400 genérico, sin distinguir el motivo. Espejo de ConfirmarReset."""
    error = ContractError(MENSAJE_RESET_INVALIDO, status_code=400)

    if not token or not _password_fuerte(nueva_password):
        raise error

    registro = PasswordResetToken.objects.filter(
        token_hash=_hash_reset_token(token)
    ).first()
    if registro is None or registro.used_at is not None:
        raise error
    if registro.expires_at <= timezone.now():
        raise error

    with transaction.atomic():
        registro.used_at = timezone.now()
        registro.save(update_fields=["used_at"])
        usuario = registro.usuario
        usuario.set_password(nueva_password)
        usuario.save(update_fields=["password"])


# ---------------------------------------------------------------------------
# CU-004/005 Perfil
# ---------------------------------------------------------------------------
def ver_perfil(usuario: Usuario) -> Perfil:
    return Perfil.objects.select_related("usuario").get(usuario=usuario)


def actualizar_perfil(usuario: Usuario, cambios: dict) -> Perfil:
    """Actualización parcial: solo se tocan las claves presentes en
    `cambios` (espejo de ActualizarPerfil.Ejecutar con campos puntero)."""
    perfil = ver_perfil(usuario)

    if "zonaHoraria" in cambios:
        zona = cambios["zonaHoraria"]
        try:
            zoneinfo.ZoneInfo(zona)
        except (zoneinfo.ZoneInfoNotFoundError, TypeError, ValueError):
            raise ContractError(
                MENSAJE_ZONA_HORARIA,
                status_code=400,
                errores={"zonaHoraria": "no es un nombre de zona horaria IANA válido"},
            ) from None
        perfil.zona_horaria = zona

    if "objetivoGeneral" in cambios:
        perfil.objetivo_general = cambios["objetivoGeneral"]

    if "accesibilidad" in cambios:
        acc = cambios["accesibilidad"] or {}
        tamano = acc.get("tamanoTexto", "")
        if tamano not in TAMANOS_TEXTO_VALIDOS:
            raise ContractError(
                MENSAJE_ACCESIBILIDAD,
                status_code=400,
                errores={
                    "accesibilidad.tamanoTexto": "debe ser normal, grande o extra_grande"
                },
            )
        perfil.tts_habilitado = bool(acc.get("ttsHabilitado", False))
        perfil.tamano_texto = tamano
        perfil.contraste_alto = bool(acc.get("contrasteAlto", False))

    if "notificaciones" in cambios:
        notif = cambios["notificaciones"] or {}
        perfil.notif_habilitadas = bool(notif.get("recordatoriosHabilitados", False))
        perfil.resumen_progreso_habilitado = bool(
            notif.get("resumenProgresoHabilitado", False)
        )

    perfil.save()
    return perfil
