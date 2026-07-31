"""Pruebas de contrato de /v1/habitos* — paridad con el backend Go."""

import pytest

from apps.habitosymetas.models import Habito

pytestmark = pytest.mark.django_db

CREAR = {
    "nombre": "Leer 20 minutos",
    "fechaInicio": "2026-07-01",
    "frecuencia": {"tipo": "diaria"},
}


def _crear(client, **overrides):
    return client.post("/v1/habitos", {**CREAR, **overrides}, format="json")


class TestCrearYListar:
    def test_201_estructura_exacta(self, auth_client):
        resp = _crear(auth_client)
        assert resp.status_code == 201
        body = resp.json()
        assert set(body.keys()) == {
            "id", "nombre", "descripcion", "fechaInicio", "frecuencia",
            "categoria", "metaId", "estado", "creadoEn",
        }
        assert body["nombre"] == "Leer 20 minutos"
        assert body["descripcion"] is None  # null explícito
        assert body["categoria"] is None
        assert body["metaId"] is None
        assert body["estado"] == "activo"
        assert body["fechaInicio"] == "2026-07-01"
        assert body["frecuencia"] == {"tipo": "diaria"}  # sin claves omitempty

    def test_frecuencia_dias_especificos(self, auth_client):
        resp = _crear(auth_client, frecuencia={"tipo": "dias_especificos",
                                               "diasSemana": [1, 3, 5]})
        assert resp.status_code == 201
        assert resp.json()["frecuencia"] == {
            "tipo": "dias_especificos", "diasSemana": [1, 3, 5]
        }

    def test_frecuencia_n_veces(self, auth_client):
        resp = _crear(auth_client, frecuencia={"tipo": "n_veces_por_periodo",
                                               "veces": 3, "periodo": "semana"})
        assert resp.status_code == 201
        assert resp.json()["frecuencia"] == {
            "tipo": "n_veces_por_periodo", "veces": 3, "periodo": "semana"
        }

    @pytest.mark.parametrize("frecuencia", [
        {"tipo": "dias_especificos"},                          # sin dias
        {"tipo": "dias_especificos", "diasSemana": []},        # vacío
        {"tipo": "dias_especificos", "diasSemana": [7]},       # fuera de rango
        {"tipo": "n_veces_por_periodo", "veces": 0, "periodo": "semana"},
        {"tipo": "n_veces_por_periodo", "veces": 2, "periodo": "trimestre"},
        {"tipo": "anual"},
        {},
    ])
    def test_400_frecuencia_invalida(self, auth_client, frecuencia):
        resp = _crear(auth_client, frecuencia=frecuencia)
        assert resp.status_code == 400
        assert resp.json() == {"mensaje": "la solicitud contiene errores de validacion"}

    def test_400_fecha_inicio_invalida(self, auth_client):
        resp = _crear(auth_client, fechaInicio="01/07/2026")
        assert resp.status_code == 400
        assert resp.json() == {"mensaje": "fecha de inicio invalida"}

    def test_400_nombre_mayor_a_120_runas(self, auth_client):
        resp = _crear(auth_client, nombre="ñ" * 121)
        assert resp.status_code == 400

    def test_400_categoria_en_blanco(self, auth_client):
        resp = _crear(auth_client, categoria="   ")
        assert resp.status_code == 400

    def test_categoria_se_recorta(self, auth_client):
        resp = _crear(auth_client, categoria="  salud  ")
        assert resp.json()["categoria"] == "salud"

    def test_listar_solo_del_usuario_y_sin_eliminados(self, auth_client, api_client):
        _crear(auth_client)
        creado = _crear(auth_client).json()
        auth_client.delete(f"/v1/habitos/{creado['id']}")
        resp = auth_client.get("/v1/habitos")
        assert resp.status_code == 200
        assert len(resp.json()) == 1

    def test_401_sin_token(self, api_client):
        assert api_client.get("/v1/habitos").status_code == 401


class TestDetalle:
    def test_404_uuid_invalido_cuerpo_contrato(self, auth_client):
        resp = auth_client.get("/v1/habitos/no-es-uuid")
        assert resp.status_code == 404
        assert resp.json() == {"mensaje": "habito no encontrado"}

    def test_404_habito_ajeno_indistinguible(self, auth_client):
        from apps.identidad.models import Usuario

        otro = Usuario.objects.create_user(
            email="otro@example.com", password="S3gura-123", nombre="Otro"
        )
        ajeno = Habito.objects.create(
            usuario=otro, nombre="Ajeno", fecha_inicio="2026-07-01",
            frecuencia_tipo="diaria",
        )
        resp = auth_client.get(f"/v1/habitos/{ajeno.id}")
        assert resp.status_code == 404
        assert resp.json() == {"mensaje": "habito no encontrado"}

    def test_patch_merge_parcial(self, auth_client):
        creado = _crear(auth_client, categoria="salud").json()
        resp = auth_client.patch(
            f"/v1/habitos/{creado['id']}", {"nombre": "Leer 30 minutos"}, format="json"
        )
        assert resp.status_code == 200
        body = resp.json()
        assert body["nombre"] == "Leer 30 minutos"
        assert body["categoria"] == "salud"  # lo no enviado se conserva
        assert body["frecuencia"] == {"tipo": "diaria"}

    def test_patch_habito_eliminado_404(self, auth_client):
        creado = _crear(auth_client).json()
        auth_client.delete(f"/v1/habitos/{creado['id']}")
        resp = auth_client.patch(
            f"/v1/habitos/{creado['id']}", {"nombre": "X"}, format="json"
        )
        assert resp.status_code == 404


class TestCicloDeVida:
    def test_pausar_y_reanudar(self, auth_client):
        creado = _crear(auth_client).json()
        resp = auth_client.post(
            f"/v1/habitos/{creado['id']}/pausar", {"inicio": "2026-07-10"}, format="json"
        )
        assert resp.status_code == 200
        assert resp.json()["estado"] == "pausado"

        resp = auth_client.post(f"/v1/habitos/{creado['id']}/reanudar")
        assert resp.status_code == 200
        assert resp.json()["estado"] == "activo"

    def test_pausar_no_activo_400_transicion(self, auth_client):
        creado = _crear(auth_client).json()
        auth_client.post(f"/v1/habitos/{creado['id']}/pausar",
                         {"inicio": "2026-07-10"}, format="json")
        resp = auth_client.post(f"/v1/habitos/{creado['id']}/pausar",
                                {"inicio": "2026-07-11"}, format="json")
        assert resp.status_code == 400
        assert resp.json() == {"mensaje": "transicion de estado invalida"}

    def test_pausar_fin_anterior_a_inicio_400(self, auth_client):
        creado = _crear(auth_client).json()
        resp = auth_client.post(
            f"/v1/habitos/{creado['id']}/pausar",
            {"inicio": "2026-07-10", "fin": "2026-07-01"}, format="json",
        )
        assert resp.status_code == 400
        assert resp.json() == {"mensaje": "la solicitud contiene errores de validacion"}

    def test_pausar_fechas_invalidas_mensajes_propios(self, auth_client):
        creado = _crear(auth_client).json()
        resp = auth_client.post(f"/v1/habitos/{creado['id']}/pausar",
                                {"inicio": "malformada"}, format="json")
        assert resp.json() == {"mensaje": "inicio invalido"}
        resp = auth_client.post(
            f"/v1/habitos/{creado['id']}/pausar",
            {"inicio": "2026-07-10", "fin": "malformada"}, format="json",
        )
        assert resp.json() == {"mensaje": "fin invalido"}

    def test_reanudar_no_pausado_400(self, auth_client):
        creado = _crear(auth_client).json()
        resp = auth_client.post(f"/v1/habitos/{creado['id']}/reanudar")
        assert resp.status_code == 400
        assert resp.json() == {"mensaje": "transicion de estado invalida"}

    def test_completar_activo_y_pausado_e_idempotente(self, auth_client):
        creado = _crear(auth_client).json()
        resp = auth_client.post(f"/v1/habitos/{creado['id']}/completar")
        assert resp.json()["estado"] == "completado"
        # idempotente: completar de nuevo sigue en 200
        resp = auth_client.post(f"/v1/habitos/{creado['id']}/completar")
        assert resp.status_code == 200
        assert resp.json()["estado"] == "completado"

    def test_eliminar_soft_con_impacto_e_idempotente(self, auth_client):
        creado = _crear(auth_client).json()
        resp = auth_client.delete(f"/v1/habitos/{creado['id']}")
        assert resp.status_code == 200
        body = resp.json()
        assert body["habito"]["estado"] == "eliminado"
        assert body["impacto"] == {"recordatoriosAfectados": 0, "registrosAfectados": 0}
        # repetir el delete sigue respondiendo 200 (fila visible para DELETE)
        assert auth_client.delete(f"/v1/habitos/{creado['id']}").status_code == 200
        # pero es 404 para todo lo demás
        assert auth_client.get(f"/v1/habitos/{creado['id']}").status_code == 404
        assert auth_client.post(f"/v1/habitos/{creado['id']}/completar").status_code == 404
