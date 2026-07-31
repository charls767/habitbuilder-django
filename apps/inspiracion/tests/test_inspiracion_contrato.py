"""Pruebas de contrato de /v1/inspiracion — usa el seed 0015 (21 filas)."""
import uuid

import pytest

from apps.inspiracion.models import ContenidoInspiracion

pytestmark = pytest.mark.django_db


class TestListado:
    def test_solo_publicados_orden_destacado_recencia(self, auth_client):
        resp = auth_client.get("/v1/inspiracion?limit=50")
        assert resp.status_code == 200
        contenidos = resp.json()
        assert len(contenidos) == 21  # seed 0015 completo (todos publicados)
        # los destacados primero
        destacados = [c["destacado"] for c in contenidos]
        assert destacados == sorted(destacados, reverse=True)
        body = contenidos[0]
        assert {"id", "tipo", "titulo", "resumen", "url", "autor", "destacado",
                "creadoEn", "actualizadoEn"} <= set(body.keys())
        assert "publicado" not in body  # campo solo-admin

    def test_no_publicado_queda_fuera(self, auth_client):
        oculto = ContenidoInspiracion.objects.first()
        ContenidoInspiracion.objects.filter(id=oculto.id).update(publicado=False)
        ids = [c["id"] for c in auth_client.get("/v1/inspiracion?limit=50").json()]
        assert str(oculto.id) not in ids

    def test_filtro_tipo(self, auth_client):
        contenidos = auth_client.get("/v1/inspiracion?tipo=video&limit=50").json()
        assert contenidos
        assert all(c["tipo"] == "video" for c in contenidos)

    def test_400_tipo_fuera_de_enum(self, auth_client):
        resp = auth_client.get("/v1/inspiracion?tipo=podcast")
        assert resp.status_code == 400
        assert resp.json() == {
            "mensaje": "la solicitud contiene errores de validacion",
            "codigo": "invalid_request",
        }

    @pytest.mark.parametrize("query", ["limit=0", "limit=51", "offset=-1"])
    def test_400_paginacion(self, auth_client, query):
        assert auth_client.get(f"/v1/inspiracion?{query}").status_code == 400

    def test_paginacion_default_20(self, auth_client):
        assert len(auth_client.get("/v1/inspiracion").json()) == 20

    def test_401_sin_token(self, api_client):
        assert api_client.get("/v1/inspiracion").status_code == 401


class TestDetalle:
    def test_200_publicado(self, auth_client):
        contenido = ContenidoInspiracion.objects.filter(publicado=True).first()
        resp = auth_client.get(f"/v1/inspiracion/{contenido.id}")
        assert resp.status_code == 200
        assert resp.json()["titulo"] == contenido.titulo
        assert resp.json()["imagenUrl"] == contenido.imagen_url

    def test_404_no_publicado(self, auth_client):
        contenido = ContenidoInspiracion.objects.first()
        ContenidoInspiracion.objects.filter(id=contenido.id).update(publicado=False)
        resp = auth_client.get(f"/v1/inspiracion/{contenido.id}")
        assert resp.status_code == 404
        assert resp.json() == {"mensaje": "contenido no encontrado", "codigo": "not_found"}

    def test_404_uuid_invalido_o_desconocido(self, auth_client):
        assert auth_client.get("/v1/inspiracion/basura").status_code == 404
        assert auth_client.get(f"/v1/inspiracion/{uuid.uuid4()}").status_code == 404
