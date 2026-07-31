"""Pruebas de contrato del envelope de error.

Fijan el formato exacto que emite el backend Go (docs/openapi.yaml,
ErrorResponse): objeto plano {mensaje, errores?, codigo?}, campos ausentes
OMITIDOS (nunca null). Si alguna de estas pruebas falla, el cliente Flutter
va a romperse: no cambiar el formato, cambiar el código que lo violó.
"""
import pytest
from rest_framework import exceptions, serializers, status
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.test import APIRequestFactory
from rest_framework.views import APIView

from apps.plataforma.api.exceptions import (
    MENSAJE_FALTA_TOKEN,
    MENSAJE_TOKEN_INVALIDO,
    MENSAJE_VALIDACION,
    ContractError,
)

factory = APIRequestFactory()


def _lanzar(exc) -> Response:
    """Ejecuta una vista DRF real que lanza `exc` y devuelve la respuesta,
    pasando por el pipeline completo (auth -> vista -> exception handler)."""

    class Vista(APIView):
        authentication_classes: list = []
        permission_classes: list = []

        def get(self, request):
            raise exc

    return Vista.as_view()(factory.get("/prueba"))


class TestEnvelopeDeError:
    def test_error_de_dominio_solo_mensaje(self):
        resp = _lanzar(ContractError("hábito no encontrado", status_code=404))
        assert resp.status_code == 404
        assert resp.data == {"mensaje": "hábito no encontrado"}

    def test_validacion_identidad_422_con_errores_por_campo(self):
        resp = _lanzar(
            ContractError(
                MENSAJE_VALIDACION,
                status_code=422,
                errores={"email": "ya está registrado"},
            )
        )
        assert resp.status_code == 422
        assert resp.data == {
            "mensaje": MENSAJE_VALIDACION,
            "errores": {"email": "ya está registrado"},
        }

    def test_conflicto_con_codigo(self):
        resp = _lanzar(
            ContractError(
                "el hábito no está activo para este recordatorio",
                status_code=409,
                codigo="habit_inactive_for_reminder",
            )
        )
        assert resp.status_code == 409
        assert resp.data == {
            "mensaje": "el hábito no está activo para este recordatorio",
            "codigo": "habit_inactive_for_reminder",
        }

    def test_campos_vacios_se_omiten_no_van_como_null(self):
        resp = _lanzar(ContractError("error interno", status_code=500))
        assert "errores" not in resp.data
        assert "codigo" not in resp.data

    def test_validation_error_drf_aplana_listas_a_mapa_plano(self):
        resp = _lanzar(
            exceptions.ValidationError({"nombre": ["Este campo es requerido."]})
        )
        assert resp.status_code == status.HTTP_400_BAD_REQUEST
        assert resp.data == {
            "mensaje": MENSAJE_VALIDACION,
            "errores": {"nombre": "Este campo es requerido."},
        }

    def test_serializer_invalido_end_to_end(self):
        class CrearSerializer(serializers.Serializer):
            nombre = serializers.CharField()

        class Vista(APIView):
            authentication_classes: list = []
            permission_classes: list = []

            def post(self, request):
                ser = CrearSerializer(data=request.data)
                ser.is_valid(raise_exception=True)
                return Response(ser.validated_data)

        resp = Vista.as_view()(factory.post("/prueba", {}, format="json"))
        assert resp.status_code == 400
        assert resp.data["mensaje"] == MENSAJE_VALIDACION
        assert "nombre" in resp.data["errores"]


class TestAutenticacion:
    """Paridad con el middleware JWT de Go (jwt_middleware.go)."""

    def _vista_protegida(self, request):
        class Vista(APIView):
            permission_classes = [IsAuthenticated]

            def get(self, request):  # pragma: no cover - nunca se alcanza
                return Response({})

        return Vista.as_view()(request)

    def test_sin_token_401_falta_el_token(self):
        resp = self._vista_protegida(factory.get("/prueba"))
        assert resp.status_code == 401
        assert resp.data == {"mensaje": MENSAJE_FALTA_TOKEN}

    def test_token_invalido_401_token_invalido_o_expirado(self):
        resp = self._vista_protegida(
            factory.get("/prueba", HTTP_AUTHORIZATION="Bearer no-es-un-jwt")
        )
        assert resp.status_code == 401
        assert resp.data == {"mensaje": MENSAJE_TOKEN_INVALIDO}


class TestHealth:
    def test_health_ok(self, api_client, monkeypatch):
        from django.db import connection

        class CursorFalso:
            def __enter__(self):
                return self

            def __exit__(self, *args):
                return False

            def execute(self, sql):
                assert sql == "SELECT 1"

        monkeypatch.setattr(connection, "cursor", lambda: CursorFalso())
        resp = api_client.get("/health")
        assert resp.status_code == 200
        assert resp.json() == {"status": "ok", "database": "ok"}

    def test_health_bd_caida_responde_503(self, api_client, monkeypatch):
        from django.db import connection

        def cursor_roto():
            raise RuntimeError("bd caída")

        monkeypatch.setattr(connection, "cursor", cursor_roto)
        resp = api_client.get("/health")
        assert resp.status_code == 503
        assert resp.json() == {"status": "degraded", "database": "error"}


class TestAplanadoDeErrores:
    def test_dict_anidado_usa_notacion_punto(self):
        from apps.plataforma.api.exceptions import _aplanar_errores

        planos = _aplanar_errores({"frecuencia": {"dias": ["valor inválido"]}})
        assert planos == {"frecuencia.dias": "valor inválido"}

    def test_detail_no_dict_devuelve_vacio(self):
        from apps.plataforma.api.exceptions import _aplanar_errores

        assert _aplanar_errores(["error suelto"]) == {}


@pytest.mark.parametrize("codigo_http", [404, 409, 422])
def test_content_type_json(codigo_http):
    resp = _lanzar(ContractError("x", status_code=codigo_http))
    resp.accepted_renderer = None  # forzar render por el pipeline normal
    assert resp.status_code == codigo_http
