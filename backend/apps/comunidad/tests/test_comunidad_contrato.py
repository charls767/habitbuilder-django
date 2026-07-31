"""Pruebas de contrato de /v1/comunidad/* — paridad con Go."""
import uuid

import pytest
from rest_framework_simplejwt.tokens import AccessToken

from apps.comunidad.models import PublicacionComunidad
from apps.identidad.models import Usuario

pytestmark = pytest.mark.django_db


@pytest.fixture
def otro_cliente(db):
    from rest_framework.test import APIClient

    otro = Usuario.objects.create_user(
        email="otro@example.com", password="S3gura-123", nombre="Otra Persona"
    )
    client = APIClient()
    client.credentials(HTTP_AUTHORIZATION=f"Bearer {AccessToken.for_user(otro)}")
    return client


def _publicar(client, contenido="Hola comunidad", **extra):
    return client.post(
        "/v1/comunidad/publicaciones", {"contenido": contenido, **extra}, format="json"
    )


class TestPublicaciones:
    def test_201_estructura(self, auth_client):
        resp = _publicar(auth_client, contenido="  Mi primer post  ")
        assert resp.status_code == 201
        body = resp.json()
        assert set(body.keys()) == {
            "id", "autorNombre", "contenido", "creadoEn", "actualizadoEn",
            "reacciones", "comentarios", "reaccionada",
        }  # habitoId omitido cuando es null
        assert body["contenido"] == "Mi primer post"  # recortado
        assert body["autorNombre"] == "Usuario Prueba"
        assert body["reacciones"] == 0
        assert body["reaccionada"] is False

    @pytest.mark.parametrize("contenido", ["", "   ", "x" * 1001])
    def test_400_contenido_invalido(self, auth_client, contenido):
        resp = _publicar(auth_client, contenido=contenido)
        assert resp.status_code == 400
        assert resp.json() == {
            "mensaje": "la solicitud contiene errores de validacion",
            "codigo": "invalid_request",
        }

    def test_habito_vinculado_propio(self, auth_client):
        habito = auth_client.post(
            "/v1/habitos",
            {"nombre": "Leer", "fechaInicio": "2026-07-01",
             "frecuencia": {"tipo": "diaria"}},
            format="json",
        ).json()
        resp = _publicar(auth_client, habitoId=habito["id"])
        assert resp.status_code == 201
        assert resp.json()["habitoId"] == habito["id"]

    def test_400_habito_uuid_invalido(self, auth_client):
        resp = _publicar(auth_client, habitoId="basura")
        assert resp.status_code == 400
        assert resp.json()["mensaje"] == "habito invalido"

    def test_404_habito_no_propio(self, auth_client):
        resp = _publicar(auth_client, habitoId=str(uuid.uuid4()))
        assert resp.status_code == 404
        assert resp.json()["mensaje"] == "habito no encontrado"

    def test_feed_nuevo_a_viejo_y_paginacion(self, auth_client):
        for i in range(3):
            _publicar(auth_client, contenido=f"post {i}")
        feed = auth_client.get("/v1/comunidad/publicaciones").json()
        assert [p["contenido"] for p in feed] == ["post 2", "post 1", "post 0"]
        pagina = auth_client.get("/v1/comunidad/publicaciones?limit=1&offset=1").json()
        assert [p["contenido"] for p in pagina] == ["post 1"]

    @pytest.mark.parametrize("query", ["limit=0", "limit=51", "offset=-1"])
    def test_400_paginacion_fuera_de_rango(self, auth_client, query):
        resp = auth_client.get(f"/v1/comunidad/publicaciones?{query}")
        assert resp.status_code == 400
        # paridad Go: el rango lo valida el service → mensaje genérico
        assert resp.json()["mensaje"] == "la solicitud contiene errores de validacion"

    def test_400_paginacion_no_numerica(self, auth_client):
        resp = auth_client.get("/v1/comunidad/publicaciones?limit=abc")
        assert resp.status_code == 400
        # paridad Go: strconv falla en el handler → mensaje específico
        assert resp.json()["mensaje"] == "parametros de paginacion invalidos"

    def test_editar_solo_el_autor(self, auth_client, otro_cliente):
        post = _publicar(auth_client).json()
        resp = otro_cliente.patch(
            f"/v1/comunidad/publicaciones/{post['id']}",
            {"contenido": "hackeado"}, format="json",
        )
        assert resp.status_code == 404  # indistinguible, nunca 403
        resp = auth_client.patch(
            f"/v1/comunidad/publicaciones/{post['id']}",
            {"contenido": "editado"}, format="json",
        )
        assert resp.status_code == 200
        assert resp.json()["contenido"] == "editado"

    def test_eliminar_soft_y_desaparece_del_feed(self, auth_client):
        post = _publicar(auth_client).json()
        assert auth_client.delete(
            f"/v1/comunidad/publicaciones/{post['id']}"
        ).status_code == 204
        assert auth_client.get("/v1/comunidad/publicaciones").json() == []
        assert auth_client.get(
            f"/v1/comunidad/publicaciones/{post['id']}"
        ).status_code == 404

    def test_publicacion_oculta_por_moderacion_no_visible(self, auth_client):
        post = _publicar(auth_client).json()
        PublicacionComunidad.objects.filter(id=post["id"]).update(
            estado_moderacion="oculto"
        )
        assert auth_client.get(
            f"/v1/comunidad/publicaciones/{post['id']}"
        ).status_code == 404


class TestComentarios:
    def test_crear_listar_viejo_a_nuevo(self, auth_client, otro_cliente):
        post = _publicar(auth_client).json()
        auth_client.post(
            f"/v1/comunidad/publicaciones/{post['id']}/comentarios",
            {"contenido": "primero"}, format="json",
        )
        resp = otro_cliente.post(
            f"/v1/comunidad/publicaciones/{post['id']}/comentarios",
            {"contenido": "segundo"}, format="json",
        )
        assert resp.status_code == 201
        assert set(resp.json().keys()) == {
            "id", "publicacionId", "autorNombre", "contenido", "creadoEn",
        }
        listado = auth_client.get(
            f"/v1/comunidad/publicaciones/{post['id']}/comentarios"
        ).json()
        assert [c["contenido"] for c in listado] == ["primero", "segundo"]
        assert listado[1]["autorNombre"] == "Otra Persona"

    def test_contador_de_comentarios_en_publicacion(self, auth_client):
        post = _publicar(auth_client).json()
        auth_client.post(
            f"/v1/comunidad/publicaciones/{post['id']}/comentarios",
            {"contenido": "hola"}, format="json",
        )
        body = auth_client.get(f"/v1/comunidad/publicaciones/{post['id']}").json()
        assert body["comentarios"] == 1

    def test_eliminar_comentario_solo_el_autor(self, auth_client, otro_cliente):
        post = _publicar(auth_client).json()
        comentario = auth_client.post(
            f"/v1/comunidad/publicaciones/{post['id']}/comentarios",
            {"contenido": "mío"}, format="json",
        ).json()
        assert otro_cliente.delete(
            f"/v1/comunidad/comentarios/{comentario['id']}"
        ).status_code == 404
        assert auth_client.delete(
            f"/v1/comunidad/comentarios/{comentario['id']}"
        ).status_code == 204

    def test_400_comentario_mayor_500(self, auth_client):
        post = _publicar(auth_client).json()
        resp = auth_client.post(
            f"/v1/comunidad/publicaciones/{post['id']}/comentarios",
            {"contenido": "x" * 501}, format="json",
        )
        assert resp.status_code == 400


class TestReacciones:
    def test_reaccionar_idempotente(self, auth_client, otro_cliente):
        post = _publicar(auth_client).json()
        url = f"/v1/comunidad/publicaciones/{post['id']}/reaccion"
        assert otro_cliente.post(url).status_code == 204
        assert otro_cliente.post(url).status_code == 204  # repetir no duplica
        body = auth_client.get(f"/v1/comunidad/publicaciones/{post['id']}").json()
        assert body["reacciones"] == 1
        assert body["reaccionada"] is False  # el autor no reaccionó

    def test_quitar_reaccion(self, auth_client):
        post = _publicar(auth_client).json()
        url = f"/v1/comunidad/publicaciones/{post['id']}/reaccion"
        auth_client.post(url)
        assert auth_client.get(
            f"/v1/comunidad/publicaciones/{post['id']}"
        ).json()["reaccionada"] is True
        assert auth_client.delete(url).status_code == 204
        assert auth_client.get(
            f"/v1/comunidad/publicaciones/{post['id']}"
        ).json()["reacciones"] == 0


class TestReportes:
    def test_201_y_409_duplicado(self, auth_client, otro_cliente):
        post = _publicar(auth_client).json()
        url = f"/v1/comunidad/publicaciones/{post['id']}/reportes"
        resp = otro_cliente.post(url, {"motivo": "spam", "detalle": "es spam"},
                                 format="json")
        assert resp.status_code == 201
        body = resp.json()
        assert set(body.keys()) == {"id", "publicacionId", "motivo", "estado", "creadoEn"}
        assert body["estado"] == "pendiente"

        resp = otro_cliente.post(url, {"motivo": "acoso"}, format="json")
        assert resp.status_code == 409
        assert resp.json() == {
            "mensaje": "la publicacion ya fue reportada por este usuario",
            "codigo": "report_already_exists",
        }

    @pytest.mark.parametrize("payload", [
        {"motivo": "molesto"}, {"motivo": ""}, {"motivo": "spam", "detalle": "x" * 501},
    ])
    def test_400_reporte_invalido(self, auth_client, otro_cliente, payload):
        post = _publicar(auth_client).json()
        resp = otro_cliente.post(
            f"/v1/comunidad/publicaciones/{post['id']}/reportes", payload, format="json"
        )
        assert resp.status_code == 400

    def test_404_publicacion_inexistente(self, auth_client):
        resp = auth_client.post(
            f"/v1/comunidad/publicaciones/{uuid.uuid4()}/reportes",
            {"motivo": "spam"}, format="json",
        )
        assert resp.status_code == 404
        assert resp.json()["mensaje"] == "publicacion no encontrada"
