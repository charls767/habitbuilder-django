"""Pruebas de los derechos GDPR: acceso (art. 15) y supresión (art. 17)."""
import pytest

from apps.comunidad.models import ComentarioComunidad, PublicacionComunidad
from apps.habitosymetas.models import Habito, MetaPersonal
from apps.identidad.models import PasswordResetToken, Perfil, Usuario
from apps.recordatorios.models import Recordatorio
from apps.seguimiento.models import RegistroHabito

pytestmark = pytest.mark.django_db

CLAVE = "S3gura-123"


@pytest.fixture
def cliente(api_client):
    """Usuario registrado por la API, con contenido en varios dominios."""
    api_client.post(
        "/v1/auth/register",
        {"nombre": "Titular Datos", "email": "titular@example.com",
         "password": CLAVE, "terminosAceptados": True},
        format="json",
    )
    token = api_client.post(
        "/v1/auth/login", {"email": "titular@example.com", "password": CLAVE},
        format="json",
    ).json()["token"]
    api_client.credentials(HTTP_AUTHORIZATION=f"Bearer {token}")

    habito = api_client.post(
        "/v1/habitos",
        {"nombre": "Leer", "fechaInicio": "2026-07-01",
         "frecuencia": {"tipo": "diaria"}},
        format="json",
    ).json()
    api_client.post(
        f"/v1/habitos/{habito['id']}/recordatorios",
        {"mensaje": "A leer", "hora": "20:00", "diasSemana": [1], "activo": True},
        format="json",
    )
    api_client.post(
        f"/v1/habitos/{habito['id']}/registros",
        {"fechaLocal": "2026-07-20", "estado": "hecho", "nota": "nota privada"},
        format="json",
    )
    api_client.post(
        "/v1/metas", {"descripcion": "Mi meta", "fechaObjetivo": "2026-12-31"},
        format="json",
    )
    api_client.post(
        "/v1/comunidad/publicaciones", {"contenido": "Hola comunidad"}, format="json"
    )
    return api_client


class TestExportacionDeDatos:
    def test_200_estructura_completa(self, cliente):
        resp = cliente.get("/v1/usuarios/me/datos")
        assert resp.status_code == 200
        body = resp.json()
        assert set(body.keys()) >= {
            "generadoEn", "usuario", "perfil", "habitos", "metas",
            "recordatorios", "registros", "comunidad",
        }
        assert set(body["usuario"].keys()) == {
            "id", "nombre", "email", "rol", "estado", "creadoEn", "consentimiento",
        }
        assert body["usuario"]["email"] == "titular@example.com"

    def test_incluye_el_contenido_de_todos_los_dominios(self, cliente):
        body = cliente.get("/v1/usuarios/me/datos").json()
        assert len(body["habitos"]) == 1
        assert len(body["metas"]) == 1
        assert len(body["recordatorios"]) == 1
        assert len(body["registros"]) == 1
        assert len(body["comunidad"]["publicaciones"]) == 1

    def test_incluye_la_nota_personal_del_registro(self, cliente):
        """La nota puede contener información de salud: el titular tiene
        derecho a recibirla en la exportación."""
        body = cliente.get("/v1/usuarios/me/datos").json()
        assert body["registros"][0]["nota"] == "nota privada"

    def test_nunca_expone_el_hash_de_la_contrasena(self, cliente):
        import json

        crudo = json.dumps(cliente.get("/v1/usuarios/me/datos").json())
        assert "argon2" not in crudo
        assert "password" not in crudo

    def test_401_sin_token(self, api_client):
        assert api_client.get("/v1/usuarios/me/datos").status_code == 401


class TestSupresionDeCuenta:
    def test_204_y_borra_todo_el_contenido(self, cliente):
        usuario = Usuario.objects.get(email="titular@example.com")
        resp = cliente.delete(
            "/v1/usuarios/me", {"password": CLAVE}, format="json"
        )
        assert resp.status_code == 204

        assert not Habito.objects.filter(usuario=usuario).exists()
        assert not MetaPersonal.objects.filter(usuario=usuario).exists()
        assert not Recordatorio.objects.filter(usuario=usuario).exists()
        assert not RegistroHabito.objects.filter(usuario=usuario).exists()
        assert not PublicacionComunidad.objects.filter(usuario=usuario).exists()
        assert not ComentarioComunidad.objects.filter(usuario=usuario).exists()
        assert not Perfil.objects.filter(usuario=usuario).exists()
        assert not PasswordResetToken.objects.filter(usuario=usuario).exists()

    def test_anonimiza_la_cuenta_en_lugar_de_dejar_rastro(self, cliente):
        usuario = Usuario.objects.get(email="titular@example.com")
        cliente.delete("/v1/usuarios/me", {"password": CLAVE}, format="json")

        usuario.refresh_from_db()
        assert usuario.nombre == "Cuenta eliminada"
        assert usuario.email != "titular@example.com"
        assert usuario.email.endswith("@invalid")
        assert not usuario.has_usable_password()

    def test_el_correo_original_deja_de_existir(self, cliente, api_client):
        cliente.delete("/v1/usuarios/me", {"password": CLAVE}, format="json")
        resp = api_client.post(
            "/v1/auth/login",
            {"email": "titular@example.com", "password": CLAVE},
            format="json",
        )
        # 401 genérico: no revela que la cuenta existió
        assert resp.status_code == 401
        assert resp.json() == {"mensaje": "correo electrónico o contraseña inválidos"}

    def test_401_con_contrasena_incorrecta(self, cliente):
        resp = cliente.delete(
            "/v1/usuarios/me", {"password": "no-es-la-clave"}, format="json"
        )
        assert resp.status_code == 401
        assert Usuario.objects.filter(email="titular@example.com").exists()

    def test_400_sin_contrasena(self, cliente):
        resp = cliente.delete("/v1/usuarios/me", {}, format="json")
        assert resp.status_code == 400
        assert "password" in resp.json()["errores"]
        assert Usuario.objects.filter(email="titular@example.com").exists()

    def test_401_sin_token(self, api_client):
        resp = api_client.delete("/v1/usuarios/me", {"password": CLAVE}, format="json")
        assert resp.status_code == 401

    def test_conserva_la_auditoria_administrativa(self, cliente):
        """La bitácora debe sobrevivir: por eso la fila del usuario se
        anonimiza en vez de borrarse."""
        from apps.administracion.models import AuditoriaAdministrativa

        usuario = Usuario.objects.get(email="titular@example.com")
        admin = Usuario.objects.create_user(
            email="admin@example.com", password=CLAVE, nombre="Admin",
            rol=Usuario.Rol.ADMIN,
        )
        AuditoriaAdministrativa.objects.create(
            actor=admin, objetivo=usuario, accion="cambiar_estado", razon="previo"
        )

        assert cliente.delete(
            "/v1/usuarios/me", {"password": CLAVE}, format="json"
        ).status_code == 204
        assert AuditoriaAdministrativa.objects.filter(objetivo=usuario).exists()
