"""Serializers DRF del dominio 'identidad'.

Los serializers de request imitan la semántica de json.Decode en Go:
campos ausentes toman su valor cero (""/false) y la validación de negocio
(mensajes exactos, 422 con errores por campo) vive en services.py. Un error
de TIPO (p. ej. terminosAceptados no booleano) equivale en Go a un fallo de
decodificación → las vistas lo convierten en 400 "cuerpo de la solicitud
inválido".

Los builders de respuesta producen los payloads byte a byte según
docs/openapi.yaml (dto.go es la referencia).
"""
from rest_framework import serializers

from .models import Perfil, Usuario


class RegistroUsuarioRequestSerializer(serializers.Serializer):
    nombre = serializers.CharField(default="", allow_blank=True, trim_whitespace=False)
    email = serializers.CharField(default="", allow_blank=True, trim_whitespace=False)
    password = serializers.CharField(default="", allow_blank=True, trim_whitespace=False)
    terminosAceptados = serializers.BooleanField(default=False)  # noqa: N815


class LoginRequestSerializer(serializers.Serializer):
    email = serializers.CharField(default="", allow_blank=True, trim_whitespace=False)
    password = serializers.CharField(default="", allow_blank=True, trim_whitespace=False)


class ResetRequestSerializer(serializers.Serializer):
    email = serializers.CharField(default="", allow_blank=True, trim_whitespace=False)


class ResetConfirmRequestSerializer(serializers.Serializer):
    token = serializers.CharField(default="", allow_blank=True, trim_whitespace=False)
    nuevaPassword = serializers.CharField(  # noqa: N815
        default="", allow_blank=True, trim_whitespace=False
    )


def usuario_dto(usuario: Usuario) -> dict:
    """UsuarioDTO de Go: proyección sin datos sensibles, nunca el hash."""
    return {
        "id": str(usuario.id),
        "nombre": usuario.nombre,
        "email": usuario.email,
        "rol": usuario.rol,
        "estado": usuario.estado,
    }


def sesion_response(token: str, expira_en) -> dict:
    return {"token": token, "expiraEn": expira_en.isoformat().replace("+00:00", "Z")}


def perfil_response(perfil: Perfil) -> dict:
    """PerfilResponse de Go: objetivoGeneral es null explícito (nunca se
    omite) cuando no hay objetivo (borde PROFILE-01)."""
    usuario = perfil.usuario
    return {
        "nombre": usuario.nombre,
        "email": usuario.email,
        "objetivoGeneral": perfil.objetivo_general,
        "zonaHoraria": perfil.zona_horaria,
        "accesibilidad": {
            "ttsHabilitado": perfil.tts_habilitado,
            "tamanoTexto": perfil.tamano_texto,
            "contrasteAlto": perfil.contraste_alto,
        },
        "notificaciones": {
            "recordatoriosHabilitados": perfil.notif_habilitadas,
            "resumenProgresoHabilitado": perfil.resumen_progreso_habilitado,
        },
    }
