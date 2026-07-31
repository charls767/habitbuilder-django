"""Pruebas de contrato de /v1/auth/* — paridad byte a byte con el backend Go
(http_handlers.go + openapi.yaml). Requieren PostgreSQL (pytest-django)."""
from datetime import timedelta

import pytest
from django.utils import timezone

from apps.identidad.models import PasswordResetToken, Perfil, Usuario
from apps.identidad.services import _hash_reset_token

pytestmark = pytest.mark.django_db

REGISTRO_OK = {
    "nombre": "Ana Prueba",
    "email": "Ana.Prueba@Example.com",
    "password": "S3gura-123",
    "terminosAceptados": True,
}


def _registrar(api_client, **overrides):
    return api_client.post("/v1/auth/register", {**REGISTRO_OK, **overrides}, format="json")


class TestRegistro:
    def test_201_estructura_exacta_y_email_normalizado(self, api_client):
        resp = _registrar(api_client)
        assert resp.status_code == 201
        body = resp.json()
        usuario = body["usuario"]
        assert set(body.keys()) == {"usuario"}
        assert set(usuario.keys()) == {"id", "nombre", "email", "rol", "estado"}
        assert usuario["nombre"] == "Ana Prueba"
        assert usuario["email"] == "ana.prueba@example.com"  # lowercased
        assert usuario["rol"] == "regular"
        assert usuario["estado"] == "activo"

    def test_crea_perfil_inicial_con_defaults(self, api_client):
        _registrar(api_client)
        perfil = Perfil.objects.get(usuario__email="ana.prueba@example.com")
        assert perfil.zona_horaria == "UTC"
        assert perfil.objetivo_general is None
        assert perfil.tamano_texto == "normal"
        assert perfil.notif_habilitadas is True
        assert perfil.resumen_progreso_habilitado is True

    def test_hash_argon2id_con_el_perfil_calibrado(self, api_client):
        """El coste está calibrado al requisito de <2s por acción; el perfil
        se mantiene por encima del mínimo OWASP (19 MiB, t=2, p=1)."""
        _registrar(api_client)
        u = Usuario.objects.get(email="ana.prueba@example.com")
        assert u.password.startswith("argon2$argon2id$")
        assert "m=32768,t=2,p=1" in u.password

    def test_verifica_y_recodifica_hashes_con_perfil_anterior(self, api_client):
        """Un hash creado con el perfil antiguo sigue siendo válido y se
        recodifica solo en el siguiente inicio de sesión."""
        from django.contrib.auth.hashers import Argon2PasswordHasher

        _registrar(api_client)
        antiguo = Argon2PasswordHasher()
        antiguo.memory_cost, antiguo.time_cost, antiguo.parallelism = 65536, 3, 4
        hash_antiguo = antiguo.encode("S3gura-123", "sal12345678901234")
        Usuario.objects.filter(email="ana.prueba@example.com").update(password=hash_antiguo)

        resp = api_client.post(
            "/v1/auth/login",
            {"email": "ana.prueba@example.com", "password": "S3gura-123"},
            format="json",
        )
        assert resp.status_code == 200

        u = Usuario.objects.get(email="ana.prueba@example.com")
        assert "m=32768,t=2,p=1" in u.password  # recodificado al perfil actual

    def test_422_reporta_todos_los_campos_a_la_vez(self, api_client):
        resp = api_client.post("/v1/auth/register", {}, format="json")
        assert resp.status_code == 422
        body = resp.json()
        assert body["mensaje"] == "la solicitud contiene errores de validación"
        assert body["errores"] == {
            "nombre": "el nombre es obligatorio",
            "email": "el correo electrónico no es válido",
            "password": "la contraseña no cumple la fortaleza mínima",
            "terminos": "debe aceptar los términos y la política de privacidad",
        }

    def test_422_email_duplicado_case_insensitive(self, api_client):
        _registrar(api_client)
        resp = _registrar(api_client, email="ANA.PRUEBA@example.com")
        assert resp.status_code == 422
        assert resp.json()["errores"] == {
            "email": "el correo electrónico ya está registrado"
        }

    def test_422_password_corta_en_runas(self, api_client):
        # 7 caracteres multibyte: Go cuenta runas, no bytes → sigue siendo corta
        resp = _registrar(api_client, email="otra@example.com", password="ñññññññ")
        assert resp.status_code == 422
        assert "password" in resp.json()["errores"]

    def test_400_tipo_invalido_es_cuerpo_invalido(self, api_client):
        resp = _registrar(api_client, terminosAceptados="no-un-booleano")
        assert resp.status_code == 400
        assert resp.json() == {"mensaje": "cuerpo de la solicitud inválido"}


class TestLogin:
    @pytest.fixture
    def registrado(self, api_client):
        _registrar(api_client)
        return {"email": "ana.prueba@example.com", "password": "S3gura-123"}

    def test_200_token_y_expira_en(self, api_client, registrado):
        resp = api_client.post("/v1/auth/login", registrado, format="json")
        assert resp.status_code == 200
        body = resp.json()
        assert set(body.keys()) == {"token", "expiraEn"}
        assert body["token"].count(".") == 2  # JWT
        assert body["expiraEn"].endswith("Z")

    def test_sub_claim_es_el_uuid_del_usuario(self, api_client, registrado):
        from rest_framework_simplejwt.tokens import AccessToken

        token = api_client.post("/v1/auth/login", registrado, format="json").json()["token"]
        u = Usuario.objects.get(email=registrado["email"])
        assert AccessToken(token)["sub"] == str(u.id)

    def test_401_password_incorrecta_mensaje_generico(self, api_client, registrado):
        resp = api_client.post(
            "/v1/auth/login",
            {"email": registrado["email"], "password": "incorrecta-123"},
            format="json",
        )
        assert resp.status_code == 401
        assert resp.json() == {"mensaje": "correo electrónico o contraseña inválidos"}

    def test_401_email_desconocido_mismo_mensaje(self, api_client):
        resp = api_client.post(
            "/v1/auth/login",
            {"email": "nadie@example.com", "password": "cualquiera-123"},
            format="json",
        )
        assert resp.status_code == 401
        assert resp.json() == {"mensaje": "correo electrónico o contraseña inválidos"}

    def test_403_cuenta_suspendida(self, api_client, registrado):
        Usuario.objects.filter(email=registrado["email"]).update(
            estado=Usuario.Estado.SUSPENDIDO
        )
        resp = api_client.post("/v1/auth/login", registrado, format="json")
        assert resp.status_code == 403
        assert resp.json() == {"mensaje": "la cuenta está suspendida"}

    def test_login_con_hash_heredado_de_go_y_rehash(self, api_client, registrado):
        """El hash Go es el PHC sin el prefijo 'argon2$' de Django. El primer
        login debe verificarlo y re-hashearlo al formato Django."""
        u = Usuario.objects.get(email=registrado["email"])
        hash_go = u.password.removeprefix("argon2")  # → "$argon2id$v=19$..."
        Usuario.objects.filter(pk=u.pk).update(password=hash_go)

        resp = api_client.post("/v1/auth/login", registrado, format="json")
        assert resp.status_code == 200

        u.refresh_from_db()
        assert u.password.startswith("argon2$argon2id$")  # re-hasheado

    def test_hash_go_password_incorrecta_401(self, api_client, registrado):
        u = Usuario.objects.get(email=registrado["email"])
        Usuario.objects.filter(pk=u.pk).update(password=u.password.removeprefix("argon2"))
        resp = api_client.post(
            "/v1/auth/login",
            {"email": registrado["email"], "password": "incorrecta-123"},
            format="json",
        )
        assert resp.status_code == 401


class TestReset:
    @pytest.fixture
    def registrado(self, api_client):
        _registrar(api_client)
        return Usuario.objects.get(email="ana.prueba@example.com")

    def test_request_200_sin_cuerpo_para_email_conocido(self, api_client, registrado):
        resp = api_client.post(
            "/v1/auth/reset/request", {"email": registrado.email}, format="json"
        )
        assert resp.status_code == 200
        assert not resp.content
        assert PasswordResetToken.objects.filter(usuario=registrado).count() == 1

    def test_request_200_para_email_desconocido_sin_crear_nada(self, api_client):
        resp = api_client.post(
            "/v1/auth/reset/request", {"email": "nadie@example.com"}, format="json"
        )
        assert resp.status_code == 200
        assert PasswordResetToken.objects.count() == 0

    def test_request_concurrente_no_duplica_token_activo(self, api_client, registrado):
        api_client.post("/v1/auth/reset/request", {"email": registrado.email}, format="json")
        resp = api_client.post(
            "/v1/auth/reset/request", {"email": registrado.email}, format="json"
        )
        assert resp.status_code == 200  # éxito genérico igualmente
        assert PasswordResetToken.objects.filter(usuario=registrado).count() == 1

    def _crear_token(self, usuario, **kwargs):
        raw = "token-de-prueba-crudo"
        PasswordResetToken.objects.create(
            usuario=usuario,
            token_hash=_hash_reset_token(raw),
            expires_at=kwargs.get("expires_at", timezone.now() + timedelta(minutes=30)),
            used_at=kwargs.get("used_at"),
        )
        return raw

    def test_confirm_200_actualiza_password(self, api_client, registrado):
        raw = self._crear_token(registrado)
        resp = api_client.post(
            "/v1/auth/reset/confirm",
            {"token": raw, "nuevaPassword": "NuevaClave-456"},
            format="json",
        )
        assert resp.status_code == 200
        login = api_client.post(
            "/v1/auth/login",
            {"email": registrado.email, "password": "NuevaClave-456"},
            format="json",
        )
        assert login.status_code == 200

    @pytest.mark.parametrize(
        "payload",
        [
            {"token": "token-inexistente", "nuevaPassword": "NuevaClave-456"},
            {"token": "", "nuevaPassword": "NuevaClave-456"},
            {"token": "token-de-prueba-crudo", "nuevaPassword": "corta"},
        ],
    )
    def test_confirm_400_generico(self, api_client, registrado, payload):
        self._crear_token(registrado)
        resp = api_client.post("/v1/auth/reset/confirm", payload, format="json")
        assert resp.status_code == 400
        assert resp.json() == {"mensaje": "token inválido, expirado, o contraseña inválida"}

    def test_confirm_400_token_usado(self, api_client, registrado):
        raw = self._crear_token(registrado, used_at=timezone.now())
        resp = api_client.post(
            "/v1/auth/reset/confirm",
            {"token": raw, "nuevaPassword": "NuevaClave-456"},
            format="json",
        )
        assert resp.status_code == 400

    def test_confirm_400_token_expirado(self, api_client, registrado):
        raw = self._crear_token(
            registrado, expires_at=timezone.now() - timedelta(minutes=1)
        )
        resp = api_client.post(
            "/v1/auth/reset/confirm",
            {"token": raw, "nuevaPassword": "NuevaClave-456"},
            format="json",
        )
        assert resp.status_code == 400


class TestLogout:
    def test_204_con_token_valido(self, auth_client):
        resp = auth_client.post("/v1/auth/logout")
        assert resp.status_code == 204
        assert not resp.content

    def test_401_sin_token(self, api_client):
        resp = api_client.post("/v1/auth/logout")
        assert resp.status_code == 401
        assert resp.json() == {"mensaje": "falta el token de autenticación"}
