"""Pruebas de contrato de /v1/usuarios/me (GET/PATCH) — paridad con Go."""
import pytest
from rest_framework_simplejwt.tokens import AccessToken

from apps.identidad.models import Usuario

pytestmark = pytest.mark.django_db


@pytest.fixture
def cliente_registrado(api_client):
    """Registra vía API (crea usuario + perfil como CU-001) y autentica."""
    api_client.post(
        "/v1/auth/register",
        {
            "nombre": "Ana Prueba",
            "email": "ana@example.com",
            "password": "S3gura-123",
            "terminosAceptados": True,
        },
        format="json",
    )
    usuario = Usuario.objects.get(email="ana@example.com")
    token = AccessToken.for_user(usuario)
    api_client.credentials(HTTP_AUTHORIZATION=f"Bearer {token}")
    return api_client


class TestVerPerfil:
    def test_200_estructura_y_defaults(self, cliente_registrado):
        resp = cliente_registrado.get("/v1/usuarios/me")
        assert resp.status_code == 200
        assert resp.json() == {
            "nombre": "Ana Prueba",
            "email": "ana@example.com",
            "objetivoGeneral": None,  # null explícito, nunca omitido
            "zonaHoraria": "UTC",
            "accesibilidad": {
                "ttsHabilitado": False,
                "tamanoTexto": "normal",
                "contrasteAlto": False,
            },
            "notificaciones": {
                "recordatoriosHabilitados": True,
                "resumenProgresoHabilitado": True,
            },
        }

    def test_401_sin_token(self, api_client):
        resp = api_client.get("/v1/usuarios/me")
        assert resp.status_code == 401
        assert resp.json() == {"mensaje": "falta el token de autenticación"}

    def test_401_token_invalido(self, api_client):
        api_client.credentials(HTTP_AUTHORIZATION="Bearer basura")
        resp = api_client.get("/v1/usuarios/me")
        assert resp.status_code == 401
        assert resp.json() == {"mensaje": "token inválido o expirado"}


class TestActualizarPerfil:
    def test_actualizacion_parcial_solo_toca_lo_enviado(self, cliente_registrado):
        resp = cliente_registrado.patch(
            "/v1/usuarios/me", {"zonaHoraria": "America/Bogota"}, format="json"
        )
        assert resp.status_code == 200
        body = resp.json()
        assert body["zonaHoraria"] == "America/Bogota"
        # lo no enviado conserva sus defaults
        assert body["accesibilidad"]["tamanoTexto"] == "normal"
        assert body["notificaciones"]["recordatoriosHabilitados"] is True

    def test_objetivo_general_set_y_null(self, cliente_registrado):
        resp = cliente_registrado.patch(
            "/v1/usuarios/me", {"objetivoGeneral": "Dormir mejor"}, format="json"
        )
        assert resp.json()["objetivoGeneral"] == "Dormir mejor"

        resp = cliente_registrado.patch(
            "/v1/usuarios/me", {"objetivoGeneral": None}, format="json"
        )
        assert resp.json()["objetivoGeneral"] is None

    def test_400_zona_horaria_invalida_cuerpo_exacto(self, cliente_registrado):
        resp = cliente_registrado.patch(
            "/v1/usuarios/me", {"zonaHoraria": "Marte/Olympus"}, format="json"
        )
        assert resp.status_code == 400
        assert resp.json() == {
            "mensaje": "zona horaria inválida",
            "errores": {"zonaHoraria": "no es un nombre de zona horaria IANA válido"},
        }

    def test_400_tamano_texto_invalido_cuerpo_exacto(self, cliente_registrado):
        resp = cliente_registrado.patch(
            "/v1/usuarios/me",
            {"accesibilidad": {"ttsHabilitado": True, "tamanoTexto": "gigante",
                               "contrasteAlto": False}},
            format="json",
        )
        assert resp.status_code == 400
        assert resp.json() == {
            "mensaje": "preferencia de accesibilidad inválida",
            "errores": {
                "accesibilidad.tamanoTexto": "debe ser normal, grande o extra_grande"
            },
        }

    def test_accesibilidad_completa_se_actualiza(self, cliente_registrado):
        resp = cliente_registrado.patch(
            "/v1/usuarios/me",
            {"accesibilidad": {"ttsHabilitado": True, "tamanoTexto": "grande",
                               "contrasteAlto": True}},
            format="json",
        )
        assert resp.status_code == 200
        assert resp.json()["accesibilidad"] == {
            "ttsHabilitado": True,
            "tamanoTexto": "grande",
            "contrasteAlto": True,
        }

    def test_notificaciones_se_actualizan(self, cliente_registrado):
        resp = cliente_registrado.patch(
            "/v1/usuarios/me",
            {"notificaciones": {"recordatoriosHabilitados": False,
                                "resumenProgresoHabilitado": False}},
            format="json",
        )
        assert resp.status_code == 200
        assert resp.json()["notificaciones"] == {
            "recordatoriosHabilitados": False,
            "resumenProgresoHabilitado": False,
        }

    def test_usuario_suspendido_con_token_vigente_aun_lee_su_perfil(self, cliente_registrado):
        """Paridad con el middleware Go: el estado NO se re-verifica por
        request; solo el login lo bloquea (CHECK_USER_IS_ACTIVE=False)."""
        Usuario.objects.filter(email="ana@example.com").update(
            estado=Usuario.Estado.SUSPENDIDO
        )
        resp = cliente_registrado.get("/v1/usuarios/me")
        assert resp.status_code == 200
