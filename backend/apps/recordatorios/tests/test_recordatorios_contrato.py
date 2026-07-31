"""Pruebas de contrato de recordatorios (rutas /v1 y alias móviles)."""
import uuid

import pytest

pytestmark = pytest.mark.django_db

CREAR_HABITO = {
    "nombre": "Meditar",
    "fechaInicio": "2026-07-01",
    "frecuencia": {"tipo": "diaria"},
}
CREAR_REC = {
    "mensaje": "Hora de meditar",
    "hora": "08:30",
    "diasSemana": [5, 1, 3],
    "activo": True,
}


@pytest.fixture
def habito(auth_client):
    return auth_client.post("/v1/habitos", CREAR_HABITO, format="json").json()


def _crear(client, habito_id, **overrides):
    return client.post(
        f"/v1/habitos/{habito_id}/recordatorios", {**CREAR_REC, **overrides},
        format="json",
    )


class TestCrear:
    def test_201_estructura_y_dias_ordenados(self, auth_client, habito):
        resp = _crear(auth_client, habito["id"])
        assert resp.status_code == 201
        body = resp.json()
        assert set(body.keys()) == {"id", "habitoId", "mensaje", "hora", "diasSemana", "activo"}
        assert body["habitoId"] == habito["id"]
        assert body["hora"] == "08:30"
        assert body["diasSemana"] == [1, 3, 5]  # normalizados ascendentes
        assert body["activo"] is True

    def test_mensaje_se_recorta(self, auth_client, habito):
        resp = _crear(auth_client, habito["id"], mensaje="  hola  ")
        assert resp.json()["mensaje"] == "hola"

    @pytest.mark.parametrize("hora", ["8:30", "24:00", "08:60", "0830", "08:30:00", ""])
    def test_400_hora_invalida(self, auth_client, habito, hora):
        resp = _crear(auth_client, habito["id"], hora=hora)
        assert resp.status_code == 400
        assert resp.json() == {
            "mensaje": "la solicitud contiene errores de validacion",
            "codigo": "invalid_request",
        }

    @pytest.mark.parametrize("dias", [[], [0], [8], [1, 1], [1, 2, 3, 4, 5, 6, 7, 1]])
    def test_400_dias_invalidos(self, auth_client, habito, dias):
        assert _crear(auth_client, habito["id"], diasSemana=dias).status_code == 400

    def test_400_mensaje_mayor_280(self, auth_client, habito):
        assert _crear(auth_client, habito["id"], mensaje="x" * 281).status_code == 400

    def test_409_habito_pausado(self, auth_client, habito):
        auth_client.post(f"/v1/habitos/{habito['id']}/pausar",
                         {"inicio": "2026-07-10"}, format="json")
        resp = _crear(auth_client, habito["id"])
        assert resp.status_code == 409
        assert resp.json() == {
            "mensaje": "el habito no esta activo para este recordatorio",
            "codigo": "habit_inactive_for_reminder",
        }

    def test_409_incluso_con_activo_false(self, auth_client, habito):
        """Go valida elegibilidad SIEMPRE en crear, aunque activo=false."""
        auth_client.post(f"/v1/habitos/{habito['id']}/completar")
        assert _crear(auth_client, habito["id"], activo=False).status_code == 409

    def test_404_habito_desconocido_es_recordatorio_no_encontrado(self, auth_client):
        """Asimetría literal de Go: el error del caso de uso pasa por
        mapDomainError y responde 'recordatorio no encontrado'."""
        resp = _crear(auth_client, str(uuid.uuid4()))
        assert resp.status_code == 404
        assert resp.json() == {"mensaje": "recordatorio no encontrado"}


class TestListar:
    def test_lista_vacia(self, auth_client, habito):
        resp = auth_client.get(f"/v1/habitos/{habito['id']}/recordatorios")
        assert resp.status_code == 200
        assert resp.json() == []

    def test_404_uuid_invalido_mensaje_habito(self, auth_client):
        resp = auth_client.get("/v1/habitos/basura/recordatorios")
        assert resp.status_code == 404
        assert resp.json() == {"mensaje": "habito no encontrado"}

    def test_404_habito_desconocido_mensaje_recordatorio(self, auth_client):
        resp = auth_client.get(f"/v1/habitos/{uuid.uuid4()}/recordatorios")
        assert resp.status_code == 404
        assert resp.json() == {"mensaje": "recordatorio no encontrado"}


class TestEditarYEliminar:
    def test_patch_reemplazo_completo(self, auth_client, habito):
        rec = _crear(auth_client, habito["id"]).json()
        resp = auth_client.patch(
            f"/v1/recordatorios/{rec['id']}",
            {"mensaje": "Nuevo", "hora": "21:15", "diasSemana": [7], "activo": False},
            format="json",
        )
        assert resp.status_code == 200
        assert resp.json() == {
            "id": rec["id"], "habitoId": habito["id"], "mensaje": "Nuevo",
            "hora": "21:15", "diasSemana": [7], "activo": False,
        }

    def test_editar_sin_reactivar_permitido_con_habito_pausado(self, auth_client, habito):
        rec = _crear(auth_client, habito["id"]).json()  # activo=True
        auth_client.post(f"/v1/habitos/{habito['id']}/pausar",
                         {"inicio": "2026-07-10"}, format="json")
        # sigue activo → no es reactivación → 200 aunque el habito esté pausado
        resp = auth_client.patch(
            f"/v1/recordatorios/{rec['id']}",
            {"mensaje": "Cambiado", "hora": "09:00", "diasSemana": [2], "activo": True},
            format="json",
        )
        assert resp.status_code == 200

    def test_409_reactivar_con_habito_pausado(self, auth_client, habito):
        rec = _crear(auth_client, habito["id"], activo=False).json()
        auth_client.post(f"/v1/habitos/{habito['id']}/pausar",
                         {"inicio": "2026-07-10"}, format="json")
        resp = auth_client.patch(
            f"/v1/recordatorios/{rec['id']}",
            {"mensaje": "X", "hora": "09:00", "diasSemana": [2], "activo": True},
            format="json",
        )
        assert resp.status_code == 409

    def test_delete_204_y_luego_404(self, auth_client, habito):
        rec = _crear(auth_client, habito["id"]).json()
        assert auth_client.delete(f"/v1/recordatorios/{rec['id']}").status_code == 204
        assert auth_client.delete(f"/v1/recordatorios/{rec['id']}").status_code == 404

    def test_404_recordatorio_ajeno(self, auth_client, habito, api_client):
        from rest_framework_simplejwt.tokens import AccessToken

        from apps.identidad.models import Usuario

        rec = _crear(auth_client, habito["id"]).json()
        otro = Usuario.objects.create_user(
            email="otro@example.com", password="S3gura-123", nombre="Otro"
        )
        api_client.credentials(
            HTTP_AUTHORIZATION=f"Bearer {AccessToken.for_user(otro)}"
        )
        resp = api_client.delete(f"/v1/recordatorios/{rec['id']}")
        assert resp.status_code == 404
        assert resp.json() == {"mensaje": "recordatorio no encontrado"}


class TestAliasMoviles:
    """Los alias en inglés viven en la RAÍZ (sin /v1) y comparten semántica."""

    def test_crear_y_listar_via_alias(self, auth_client, habito):
        resp = auth_client.post(
            f"/habits/{habito['id']}/reminders", CREAR_REC, format="json"
        )
        assert resp.status_code == 201
        rec = resp.json()

        listado = auth_client.get(f"/habits/{habito['id']}/reminders")
        assert listado.status_code == 200
        assert [r["id"] for r in listado.json()] == [rec["id"]]

        # visible también por la ruta en español (misma tabla)
        assert auth_client.get(
            f"/v1/habitos/{habito['id']}/recordatorios"
        ).json() == listado.json()

    def test_editar_y_eliminar_via_alias(self, auth_client, habito):
        rec = _crear(auth_client, habito["id"]).json()
        resp = auth_client.patch(
            f"/reminders/{rec['id']}",
            {"mensaje": "Alias", "hora": "10:00", "diasSemana": [6], "activo": True},
            format="json",
        )
        assert resp.status_code == 200
        assert resp.json()["mensaje"] == "Alias"
        assert auth_client.delete(f"/reminders/{rec['id']}").status_code == 204
