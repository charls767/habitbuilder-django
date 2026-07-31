"""Pruebas de contrato de /v1/habitos/{id}/registros — paridad con Go."""
import uuid
from datetime import date, timedelta

import pytest

from apps.progreso.models import RachaHabito

pytestmark = pytest.mark.django_db

REGISTRO = {"fechaLocal": "2026-07-20", "estado": "hecho"}


@pytest.fixture
def cliente(api_client):
    """Cliente registrado vía API (con perfil, requerido por seguimiento)."""
    api_client.post(
        "/v1/auth/register",
        {"nombre": "Ana", "email": "ana@example.com", "password": "S3gura-123",
         "terminosAceptados": True},
        format="json",
    )
    token = api_client.post(
        "/v1/auth/login", {"email": "ana@example.com", "password": "S3gura-123"},
        format="json",
    ).json()["token"]
    api_client.credentials(HTTP_AUTHORIZATION=f"Bearer {token}")
    return api_client


@pytest.fixture
def habito(cliente):
    return cliente.post(
        "/v1/habitos",
        {"nombre": "Leer", "fechaInicio": "2026-07-01", "frecuencia": {"tipo": "diaria"}},
        format="json",
    ).json()


def _registrar(cliente, habito_id, **overrides):
    return cliente.post(
        f"/v1/habitos/{habito_id}/registros", {**REGISTRO, **overrides}, format="json"
    )


class TestUpsert:
    def test_201_creacion_y_estructura(self, cliente, habito):
        resp = _registrar(cliente, habito["id"], nota="  buena sesión  ")
        assert resp.status_code == 201
        body = resp.json()
        assert set(body.keys()) == {
            "id", "habitoId", "fechaLocal", "creadoEn", "actualizadoEn", "estado", "nota",
        }
        assert body["fechaLocal"] == "2026-07-20"
        assert body["nota"] == "buena sesión"  # recortada

    def test_nota_null_se_omite(self, cliente, habito):
        body = _registrar(cliente, habito["id"]).json()
        assert "nota" not in body  # omitempty

    def test_200_upsert_mismo_dia_sobrescribe(self, cliente, habito):
        creado = _registrar(cliente, habito["id"]).json()
        resp = _registrar(cliente, habito["id"], estado="parcial")
        assert resp.status_code == 200  # señal editar, no crear
        body = resp.json()
        assert body["id"] == creado["id"]  # misma fila (clave natural)
        assert body["estado"] == "parcial"

    def test_registro_permitido_con_habito_pausado(self, cliente, habito):
        cliente.post(f"/v1/habitos/{habito['id']}/pausar",
                     {"inicio": "2026-07-10"}, format="json")
        assert _registrar(cliente, habito["id"]).status_code == 201

    def test_400_fecha_futura(self, cliente, habito):
        futura = (date.today() + timedelta(days=2)).isoformat()
        resp = _registrar(cliente, habito["id"], fechaLocal=futura)
        assert resp.status_code == 400
        assert resp.json() == {
            "mensaje": "la solicitud contiene errores de validacion",
            "codigo": "invalid_request",
        }

    @pytest.mark.parametrize("payload", [
        {"estado": "completado"},
        {"fechaLocal": "20/07/2026"},
        {"nota": "x" * 501},
    ])
    def test_400_validacion(self, cliente, habito, payload):
        assert _registrar(cliente, habito["id"], **payload).status_code == 400

    def test_404_habito_desconocido(self, cliente):
        resp = _registrar(cliente, str(uuid.uuid4()))
        assert resp.status_code == 404
        assert resp.json() == {"mensaje": "habito no encontrado"}

    def test_actualiza_racha(self, cliente, habito):
        hoy = date.today()
        for delta in (1, 0):
            _registrar(cliente, habito["id"],
                       fechaLocal=(hoy - timedelta(days=delta)).isoformat())
        racha = RachaHabito.objects.get(habito_id=habito["id"])
        assert racha.racha_actual == 2
        assert racha.racha_mas_larga == 2


class TestListar:
    def test_orden_por_fecha_y_filtros(self, cliente, habito):
        for f in ("2026-07-22", "2026-07-20", "2026-07-21"):
            _registrar(cliente, habito["id"], fechaLocal=f)
        resp = cliente.get(f"/v1/habitos/{habito['id']}/registros")
        fechas = [r["fechaLocal"] for r in resp.json()]
        assert fechas == ["2026-07-20", "2026-07-21", "2026-07-22"]

        resp = cliente.get(
            f"/v1/habitos/{habito['id']}/registros?desde=2026-07-21&hasta=2026-07-21"
        )
        assert [r["fechaLocal"] for r in resp.json()] == ["2026-07-21"]

    def test_400_parametro_de_fecha_invalido(self, cliente, habito):
        resp = cliente.get(f"/v1/habitos/{habito['id']}/registros?desde=ayer")
        assert resp.status_code == 400
        assert resp.json() == {
            "mensaje": "parametro de fecha invalido",
            "codigo": "invalid_request",
        }

    def test_404_habito_ajeno(self, cliente):
        from apps.habitosymetas.models import Habito
        from apps.identidad.models import Usuario

        otro = Usuario.objects.create_user(
            email="otro@example.com", password="S3gura-123", nombre="Otro"
        )
        ajeno = Habito.objects.create(
            usuario=otro, nombre="Ajeno", fecha_inicio="2026-07-01",
            frecuencia_tipo="diaria",
        )
        resp = cliente.get(f"/v1/habitos/{ajeno.id}/registros")
        assert resp.status_code == 404
