"""Pruebas de contrato de /v1/metas* — paridad con el backend Go."""
import uuid

import pytest

pytestmark = pytest.mark.django_db

CREAR_META = {"descripcion": "Mejorar mi salud", "fechaObjetivo": "2026-12-31"}
CREAR_HABITO = {
    "nombre": "Caminar",
    "fechaInicio": "2026-07-01",
    "frecuencia": {"tipo": "diaria"},
}


def _meta(client, **overrides):
    return client.post("/v1/metas", {**CREAR_META, **overrides}, format="json")


def _habito(client):
    return client.post("/v1/habitos", CREAR_HABITO, format="json").json()


class TestCrudMetas:
    def test_201_estructura(self, auth_client):
        resp = _meta(auth_client)
        assert resp.status_code == 201
        body = resp.json()
        assert set(body.keys()) == {"id", "descripcion", "fechaObjetivo", "estado", "creadoEn"}
        assert body["estado"] == "en_progreso"
        assert body["fechaObjetivo"] == "2026-12-31"

    def test_400_descripcion_vacia(self, auth_client):
        resp = _meta(auth_client, descripcion="")
        assert resp.status_code == 400
        assert resp.json() == {"mensaje": "la solicitud contiene errores de validacion"}

    def test_400_fecha_objetivo_invalida(self, auth_client):
        resp = _meta(auth_client, fechaObjetivo="pronto")
        assert resp.status_code == 400
        assert resp.json() == {"mensaje": "fecha objetivo invalida"}

    def test_listar_y_obtener(self, auth_client):
        creada = _meta(auth_client).json()
        assert len(auth_client.get("/v1/metas").json()) == 1
        assert auth_client.get(f"/v1/metas/{creada['id']}").json() == creada

    def test_404_meta_inexistente_o_uuid_invalido(self, auth_client):
        assert auth_client.get(f"/v1/metas/{uuid.uuid4()}").json() == {
            "mensaje": "meta no encontrada"
        }
        assert auth_client.get("/v1/metas/basura").status_code == 404

    def test_patch_merge_parcial(self, auth_client):
        creada = _meta(auth_client).json()
        resp = auth_client.patch(
            f"/v1/metas/{creada['id']}", {"descripcion": "Salud integral"}, format="json"
        )
        assert resp.status_code == 200
        assert resp.json()["descripcion"] == "Salud integral"
        assert resp.json()["fechaObjetivo"] == "2026-12-31"


class TestEstadoMeta:
    def test_estado_lo_fija_el_caller(self, auth_client):
        creada = _meta(auth_client).json()
        resp = auth_client.patch(
            f"/v1/metas/{creada['id']}/estado", {"estado": "lograda"}, format="json"
        )
        assert resp.status_code == 200
        assert resp.json()["estado"] == "lograda"

    def test_400_estado_invalido(self, auth_client):
        creada = _meta(auth_client).json()
        resp = auth_client.patch(
            f"/v1/metas/{creada['id']}/estado", {"estado": "terminada"}, format="json"
        )
        assert resp.status_code == 400
        assert resp.json() == {"mensaje": "la solicitud contiene errores de validacion"}


class TestVinculacion:
    def test_vincular_y_desvincular(self, auth_client):
        meta = _meta(auth_client).json()
        habito = _habito(auth_client)
        resp = auth_client.post(
            f"/v1/metas/{meta['id']}/habitos",
            {"habitoIds": [habito["id"], habito["id"]]},  # repetidos se colapsan
            format="json",
        )
        assert resp.status_code == 200
        assert auth_client.get(f"/v1/habitos/{habito['id']}").json()["metaId"] == meta["id"]

        resp = auth_client.delete(f"/v1/metas/{meta['id']}/habitos/{habito['id']}")
        assert resp.status_code == 204
        assert auth_client.get(f"/v1/habitos/{habito['id']}").json()["metaId"] is None

    def test_404_si_algun_habito_no_es_propio(self, auth_client):
        from apps.habitosymetas.models import Habito
        from apps.identidad.models import Usuario

        meta = _meta(auth_client).json()
        propio = _habito(auth_client)
        otro = Usuario.objects.create_user(
            email="otro@example.com", password="S3gura-123", nombre="Otro"
        )
        ajeno = Habito.objects.create(
            usuario=otro, nombre="Ajeno", fecha_inicio="2026-07-01",
            frecuencia_tipo="diaria",
        )
        resp = auth_client.post(
            f"/v1/metas/{meta['id']}/habitos",
            {"habitoIds": [propio["id"], str(ajeno.id)]},
            format="json",
        )
        assert resp.status_code == 404
        assert resp.json() == {"mensaje": "habito no encontrado"}
        # y nada quedó vinculado
        assert auth_client.get(f"/v1/habitos/{propio['id']}").json()["metaId"] is None

    def test_404_lista_vacia_o_uuid_invalido(self, auth_client):
        meta = _meta(auth_client).json()
        assert auth_client.post(
            f"/v1/metas/{meta['id']}/habitos", {"habitoIds": []}, format="json"
        ).status_code == 404
        assert auth_client.post(
            f"/v1/metas/{meta['id']}/habitos", {"habitoIds": ["basura"]}, format="json"
        ).status_code == 404

    def test_desvincular_no_vinculado_404(self, auth_client):
        meta = _meta(auth_client).json()
        habito = _habito(auth_client)  # existe pero no está vinculado
        resp = auth_client.delete(f"/v1/metas/{meta['id']}/habitos/{habito['id']}")
        assert resp.status_code == 404
        assert resp.json() == {"mensaje": "habito no encontrado"}
