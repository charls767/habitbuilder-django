"""Vistas DRF del dominio 'identidad' (adaptadores HTTP).

Equivalen 1:1 a los handlers de chi en http_handlers.go: decodificar,
delegar al caso de uso, serializar. Sin lógica de negocio.
"""
from rest_framework import status
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.plataforma.api.exceptions import MENSAJE_CUERPO_INVALIDO, ContractError

from . import serializers, services


def _validar_cuerpo(serializer_cls, data):
    """Un error de tipo en el JSON equivale al fallo de json.Decode en Go:
    400 'cuerpo de la solicitud inválido' (sin detalle por campo)."""
    ser = serializer_cls(data=data)
    if not ser.is_valid():
        raise ContractError(MENSAJE_CUERPO_INVALIDO, status_code=400)
    return ser.validated_data


class RegistroView(APIView):
    authentication_classes: list = []
    permission_classes = [AllowAny]

    def post(self, request):
        datos = _validar_cuerpo(serializers.RegistroUsuarioRequestSerializer, request.data)
        usuario = services.registrar_usuario(
            nombre=datos["nombre"],
            email=datos["email"],
            password=datos["password"],
            terminos_aceptados=datos["terminosAceptados"],
        )
        return Response(
            {"usuario": serializers.usuario_dto(usuario)},
            status=status.HTTP_201_CREATED,
        )


class LoginView(APIView):
    authentication_classes: list = []
    permission_classes = [AllowAny]

    def post(self, request):
        datos = _validar_cuerpo(serializers.LoginRequestSerializer, request.data)
        sesion = services.iniciar_sesion(
            email=datos["email"], password=datos["password"]
        )
        return Response(serializers.sesion_response(sesion.token, sesion.expira_en))


class ResetRequestView(APIView):
    authentication_classes: list = []
    permission_classes = [AllowAny]

    def post(self, request):
        datos = _validar_cuerpo(serializers.ResetRequestSerializer, request.data)
        services.solicitar_reset(email=datos["email"])
        return Response(status=status.HTTP_200_OK)  # siempre 200, sin cuerpo


class ResetConfirmView(APIView):
    authentication_classes: list = []
    permission_classes = [AllowAny]

    def post(self, request):
        datos = _validar_cuerpo(serializers.ResetConfirmRequestSerializer, request.data)
        services.confirmar_reset(
            token=datos["token"], nueva_password=datos["nuevaPassword"]
        )
        return Response(status=status.HTTP_200_OK)


class LogoutView(APIView):
    """No-op sin estado (PROFILE-05): exige JWT válido y responde 204.
    El token NO se revoca en servidor; el cliente lo descarta."""

    def post(self, request):
        return Response(status=status.HTTP_204_NO_CONTENT)


class PerfilView(APIView):
    def get(self, request):
        perfil = services.ver_perfil(request.user)
        return Response(serializers.perfil_response(perfil))

    def patch(self, request):
        if not isinstance(request.data, dict):
            raise ContractError(MENSAJE_CUERPO_INVALIDO, status_code=400)
        perfil = services.actualizar_perfil(request.user, request.data)
        return Response(serializers.perfil_response(perfil))
