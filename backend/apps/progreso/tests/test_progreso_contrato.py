"""Pruebas de contrato de /v1/progreso, /v1/habitos/{id}/progreso y
/v1/estadisticas — incluye pruebas unitarias del algoritmo de racha."""
import uuid
from datetime import date, timedelta

import pytest

from apps.progreso.services import Frecuencia, Pausa, calcular_racha, rango_de_periodo

pytestmark = pytest.mark.django_db


@pytest.fixture
def cliente(api_client):
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


def _habito(cliente, **overrides):
    base = {"nombre": "Leer", "fechaInicio": date.today().isoformat(),
            "frecuencia": {"tipo": "diaria"}}
    return cliente.post("/v1/habitos", {**base, **overrides}, format="json").json()


def _registrar(cliente, habito_id, fecha, estado="hecho"):
    return cliente.post(
        f"/v1/habitos/{habito_id}/registros",
        {"fechaLocal": fecha.isoformat(), "estado": estado}, format="json",
    )


class TestAlgoritmoRacha:
    """Unitarias puras del espejo de CalcularRacha (sin BD)."""

    def test_diaria_racha_simple(self):
        hoy = date(2026, 7, 20)
        registros = [(hoy - timedelta(days=d), "hecho") for d in (0, 1, 2)]
        frec = Frecuencia(tipo="diaria")
        actual, larga = calcular_racha(frec, hoy - timedelta(days=5), registros, hoy)
        assert (actual, larga) == (3, 3)

    def test_hoy_incompleto_no_rompe_racha(self):
        hoy = date(2026, 7, 20)
        registros = [(hoy - timedelta(days=d), "hecho") for d in (1, 2)]
        frec = Frecuencia(tipo="diaria")
        actual, larga = calcular_racha(frec, hoy - timedelta(days=5), registros, hoy)
        assert actual == 2  # hoy sigue abierto: no penaliza

    def test_hueco_reinicia_racha_actual(self):
        hoy = date(2026, 7, 20)
        registros = [(hoy - timedelta(days=d), "hecho") for d in (0, 2, 3, 4)]
        frec = Frecuencia(tipo="diaria")
        actual, larga = calcular_racha(frec, hoy - timedelta(days=6), registros, hoy)
        assert (actual, larga) == (1, 3)

    def test_parcial_no_cuenta_como_completado(self):
        hoy = date(2026, 7, 20)
        registros = [(hoy, "parcial"), (hoy - timedelta(days=1), "hecho")]
        frec = Frecuencia(tipo="diaria")
        actual, _ = calcular_racha(frec, hoy - timedelta(days=3), registros, hoy)
        assert actual == 1

    def test_dias_especificos_solo_cuenta_programados(self):
        # lunes=1 y miércoles=3 en convención Go (domingo=0)
        hoy = date(2026, 7, 22)  # miércoles
        lunes = date(2026, 7, 20)
        frec = Frecuencia(tipo="dias_especificos", dias_semana=(1, 3))
        registros = [(lunes, "hecho"), (hoy, "hecho")]
        actual, larga = calcular_racha(frec, date(2026, 7, 19), registros, hoy)
        assert (actual, larga) == (2, 2)

    def test_n_veces_por_semana(self):
        hoy = date(2026, 7, 22)  # semana ISO del 20 al 26
        frec = Frecuencia(tipo="n_veces_por_periodo", veces=2, periodo="semana")
        registros = [
            (date(2026, 7, 14), "hecho"), (date(2026, 7, 15), "hecho"),  # semana previa
            (date(2026, 7, 20), "hecho"), (date(2026, 7, 21), "hecho"),  # esta semana
        ]
        actual, larga = calcular_racha(frec, date(2026, 7, 13), registros, hoy)
        assert (actual, larga) == (2, 2)

    def test_rango_de_periodo_semana_iso(self):
        desde, hasta = rango_de_periodo("semana", date(2026, 7, 22))
        assert (desde, hasta) == (date(2026, 7, 20), date(2026, 7, 26))
        # domingo pertenece a la semana que TERMINA ese día
        desde, hasta = rango_de_periodo("semana", date(2026, 7, 26))
        assert (desde, hasta) == (date(2026, 7, 20), date(2026, 7, 26))

    def test_rango_de_periodo_mes(self):
        assert rango_de_periodo("mes", date(2026, 2, 10)) == (
            date(2026, 2, 1), date(2026, 2, 28)
        )

    def test_pausa_excluye_dias(self):
        hoy = date(2026, 7, 20)
        frec = Frecuencia(tipo="diaria")
        registros = [(hoy - timedelta(days=d), "hecho") for d in (0, 3)]
        pausas = [Pausa(inicio=hoy - timedelta(days=2), fin=hoy - timedelta(days=1))]
        actual, larga = calcular_racha(
            frec, hoy - timedelta(days=3), registros, hoy, pausas
        )
        assert (actual, larga) == (2, 2)  # los días pausados no rompen


class TestProgresoEndpoints:
    def test_progreso_habito_con_datos(self, cliente):
        habito = _habito(cliente)
        _registrar(cliente, habito["id"], date.today())
        resp = cliente.get(f"/v1/habitos/{habito['id']}/progreso")
        assert resp.status_code == 200
        body = resp.json()
        assert set(body.keys()) == {
            "habitoId", "periodoDesde", "periodoHasta", "rachaActual",
            "rachaMasLarga", "porcentaje", "estado",
        }
        assert body["estado"] == "con_datos"
        assert body["rachaActual"] == 1

    def test_progreso_sin_registros_es_sin_datos(self, cliente):
        habito = _habito(cliente)
        body = cliente.get(f"/v1/habitos/{habito['id']}/progreso").json()
        assert body["estado"] == "sin_datos"
        assert body["porcentaje"] == 0

    def test_400_periodo_fuera_de_enum(self, cliente):
        habito = _habito(cliente)
        resp = cliente.get(f"/v1/habitos/{habito['id']}/progreso?periodo=anual")
        assert resp.status_code == 400
        assert resp.json() == {
            "mensaje": "la solicitud contiene errores de validacion",
            "codigo": "invalid_request",
        }

    def test_404_habito_desconocido(self, cliente):
        resp = cliente.get(f"/v1/habitos/{uuid.uuid4()}/progreso")
        assert resp.status_code == 404
        assert resp.json() == {"mensaje": "habito no encontrado"}

    def test_lista_progreso_excluye_eliminados(self, cliente):
        h1 = _habito(cliente)
        h2 = _habito(cliente, nombre="Otro")
        cliente.delete(f"/v1/habitos/{h2['id']}")
        body = cliente.get("/v1/progreso").json()
        assert [p["habitoId"] for p in body] == [h1["id"]]

    def test_404_perfil_no_encontrado(self, auth_client):
        """El usuario del fixture global no tiene Perfil: paridad con el
        mapper de Go (ErrPerfilNoEncontrado → 404)."""
        habito = auth_client.post(
            "/v1/habitos",
            {"nombre": "X", "fechaInicio": "2026-07-01",
             "frecuencia": {"tipo": "diaria"}},
            format="json",
        ).json()
        resp = auth_client.get(f"/v1/habitos/{habito['id']}/progreso")
        assert resp.status_code == 404
        assert resp.json() == {"mensaje": "perfil no encontrado"}


class TestEstadisticas:
    def test_estructura_y_orden(self, cliente):
        h1 = _habito(cliente, nombre="Alta")
        h2 = _habito(cliente, nombre="Baja")
        _registrar(cliente, h1["id"], date.today())
        _registrar(cliente, h2["id"], date.today(), estado="omitido")
        body = cliente.get("/v1/estadisticas").json()
        assert set(body.keys()) == {
            "periodoDesde", "periodoHasta", "porcentaje", "mejorRacha",
            "masConsistentes", "masOmitidos", "estado",
        }
        assert body["estado"] == "con_datos"
        assert body["masConsistentes"][0]["habitoId"] == h1["id"]
        assert body["masOmitidos"][0]["habitoId"] == h2["id"]
        entrada = body["masConsistentes"][0]
        assert set(entrada.keys()) == {
            "habitoId", "nombre", "porcentaje", "rachaMasLarga",
            "totalHecho", "totalOmitido",
        }

    def test_sin_habitos_es_insuficiente(self, cliente):
        body = cliente.get("/v1/estadisticas").json()
        assert body["estado"] == "insuficiente"
        assert body["masConsistentes"] == []

    def test_incluye_habitos_eliminados_stats03(self, cliente):
        habito = _habito(cliente)
        _registrar(cliente, habito["id"], date.today())
        cliente.delete(f"/v1/habitos/{habito['id']}")
        body = cliente.get("/v1/estadisticas").json()
        assert body["estado"] == "con_datos"  # el histórico sigue disponible
        assert body["masConsistentes"][0]["habitoId"] == habito["id"]

    def test_filtro_habito_no_propio_404(self, cliente):
        resp = cliente.get(f"/v1/estadisticas?habitoId={uuid.uuid4()}")
        assert resp.status_code == 404
        assert resp.json() == {"mensaje": "habito no encontrado"}

    def test_habito_propio_excluido_por_categoria_es_200(self, cliente):
        habito = _habito(cliente, categoria="salud")
        _registrar(cliente, habito["id"], date.today())
        resp = cliente.get(
            f"/v1/estadisticas?habitoId={habito['id']}&categoria=finanzas"
        )
        assert resp.status_code == 200  # filtros independientes, nunca 404
        assert resp.json()["estado"] == "insuficiente"
