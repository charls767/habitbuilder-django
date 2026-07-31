"""Pruebas de contrato de /v1/admin/* y /v1/solicitudes-administrador*."""
import uuid

import pytest
from rest_framework.test import APIClient
from rest_framework_simplejwt.tokens import AccessToken

from apps.administracion.models import AuditoriaAdministrativa
from apps.identidad.models import Usuario

pytestmark = pytest.mark.django_db


def _cliente_de(usuario) -> APIClient:
    client = APIClient()
    client.credentials(HTTP_AUTHORIZATION=f"Bearer {AccessToken.for_user(usuario)}")
    return client


@pytest.fixture
def admin(db):
    return Usuario.objects.create_user(
        email="admin@example.com", password="S3gura-123", nombre="Admin",
        rol=Usuario.Rol.ADMIN,
    )


@pytest.fixture
def admin_client(admin):
    return _cliente_de(admin)


class TestRequireAdmin:
    @pytest.mark.parametrize("ruta", [
        "/v1/admin/usuarios", "/v1/admin/reportes/uso",
        "/v1/admin/moderacion/reportes", "/v1/admin/inspiracion",
        "/v1/admin/solicitudes-administrador",
    ])
    def test_403_para_rol_regular(self, auth_client, ruta):
        resp = auth_client.get(ruta)
        assert resp.status_code == 403
        assert resp.json() == {
            "mensaje": "se requiere rol administrador", "codigo": "forbidden",
        }

    def test_401_sin_token(self, api_client):
        assert api_client.get("/v1/admin/usuarios").status_code == 401


class TestUsuariosAdmin:
    def test_listado_estructura_sin_secretos(self, admin_client, usuario):
        resp = admin_client.get("/v1/admin/usuarios")
        assert resp.status_code == 200
        body = resp.json()
        assert len(body) == 2
        assert set(body[0].keys()) == {"id", "nombre", "email", "rol", "estado"}

    def test_filtros_estado_rol_buscar(self, admin_client, usuario):
        assert len(admin_client.get("/v1/admin/usuarios?rol=admin").json()) == 1
        assert len(admin_client.get("/v1/admin/usuarios?estado=activo").json()) == 2
        encontrados = admin_client.get("/v1/admin/usuarios?buscar=prueba").json()
        assert [u["email"] for u in encontrados] == ["test@habitbuilder.dev"]

    @pytest.mark.parametrize("query", ["rol=dios", "limit=abc"])
    def test_400_filtros_invalidos(self, admin_client, query):
        resp = admin_client.get(f"/v1/admin/usuarios?{query}")
        assert resp.status_code == 400
        assert resp.json() == {
            "mensaje": "la solicitud contiene errores de validacion",
            "codigo": "invalid_request",
        }

    def test_quirks_de_go_en_filtros(self, admin_client):
        """Paridad verificada contra el binario Go real (tools/parity.py):
        estado fuera de enum NO se valida (200 []), y limit va directo al
        SQL sin validar rango."""
        resp = admin_client.get("/v1/admin/usuarios?estado=congelado")
        assert resp.status_code == 200
        assert resp.json() == []
        assert admin_client.get("/v1/admin/usuarios?limit=0").json() == []
        assert admin_client.get("/v1/admin/usuarios?limit=101").status_code == 200

    def test_suspender_usuario_con_auditoria(self, admin_client, admin, usuario):
        resp = admin_client.patch(
            f"/v1/admin/usuarios/{usuario.id}/estado",
            {"estado": "suspendido", "razon": "incumplió las normas"},
            format="json",
        )
        assert resp.status_code == 204
        usuario.refresh_from_db()
        assert usuario.estado == "suspendido"
        rastro = AuditoriaAdministrativa.objects.get(objetivo=usuario)
        assert rastro.actor == admin
        assert rastro.accion == "cambiar_estado"

    def test_400_cambiarse_a_si_mismo(self, admin_client, admin):
        resp = admin_client.patch(
            f"/v1/admin/usuarios/{admin.id}/estado",
            {"estado": "suspendido", "razon": "x"}, format="json",
        )
        assert resp.status_code == 400

    def test_409_ultimo_admin_no_se_suspende(self, admin, usuario):
        otro_admin = Usuario.objects.create_user(
            email="admin2@example.com", password="S3gura-123", nombre="Admin2",
            rol=Usuario.Rol.ADMIN,
        )
        cliente2 = _cliente_de(otro_admin)
        Usuario.objects.filter(id=otro_admin.id).update(estado="suspendido")
        # admin es ahora el único admin activo; otro_admin intenta suspenderlo
        resp = cliente2.patch(
            f"/v1/admin/usuarios/{admin.id}/estado",
            {"estado": "suspendido", "razon": "x"}, format="json",
        )
        assert resp.status_code == 409
        assert resp.json() == {
            "mensaje": "no se puede desactivar el ultimo administrador",
            "codigo": "last_admin_protection",
        }

    def test_409_ultimo_admin_no_se_degrada(self, admin):
        # actor: admin suspendido (conserva el rol); objetivo: único admin activo
        suspendido = Usuario.objects.create_user(
            email="admin2@example.com", password="S3gura-123", nombre="Admin2",
            rol=Usuario.Rol.ADMIN, estado=Usuario.Estado.SUSPENDIDO,
        )
        resp = _cliente_de(suspendido).patch(
            f"/v1/admin/usuarios/{admin.id}/rol",
            {"rol": "regular", "razon": "x"}, format="json",
        )
        assert resp.status_code == 409
        assert resp.json()["codigo"] == "last_admin_protection"

    def test_degradar_admin_suspendido_si_hay_otro_activo(self, admin_client, admin):
        # un admin suspendido no es el "último activo": degradarlo procede
        suspendido = Usuario.objects.create_user(
            email="admin2@example.com", password="S3gura-123", nombre="Admin2",
            rol=Usuario.Rol.ADMIN, estado=Usuario.Estado.SUSPENDIDO,
        )
        resp = admin_client.patch(
            f"/v1/admin/usuarios/{suspendido.id}/rol",
            {"rol": "regular", "razon": "limpieza"}, format="json",
        )
        assert resp.status_code == 204

    def test_promover_a_admin(self, admin_client, usuario):
        resp = admin_client.patch(
            f"/v1/admin/usuarios/{usuario.id}/rol",
            {"rol": "admin", "razon": "promoción"}, format="json",
        )
        assert resp.status_code == 204
        usuario.refresh_from_db()
        assert usuario.rol == "admin"

    def test_404_usuario_inexistente(self, admin_client):
        resp = admin_client.patch(
            f"/v1/admin/usuarios/{uuid.uuid4()}/estado",
            {"estado": "suspendido", "razon": "x"}, format="json",
        )
        assert resp.status_code == 404
        assert resp.json() == {"mensaje": "usuario no encontrado", "codigo": "not_found"}

    @pytest.mark.parametrize("razon", ["", "   ", "x" * 501])
    def test_400_razon_invalida(self, admin_client, usuario, razon):
        resp = admin_client.patch(
            f"/v1/admin/usuarios/{usuario.id}/estado",
            {"estado": "suspendido", "razon": razon}, format="json",
        )
        assert resp.status_code == 400


class TestReporteUso:
    def test_estructura_y_conteos(self, admin_client, auth_client, usuario):
        auth_client.post(
            "/v1/habitos",
            {"nombre": "Leer", "fechaInicio": "2026-07-01",
             "frecuencia": {"tipo": "diaria"}},
            format="json",
        )
        resp = admin_client.get("/v1/admin/reportes/uso")
        assert resp.status_code == 200
        body = resp.json()
        assert set(body.keys()) == {
            "periodoDesde", "periodoHasta", "usuariosRegistrados",
            "usuariosActivos", "habitosCreados", "registrosCreados", "publicaciones",
        }
        assert body["usuariosRegistrados"] == 2
        assert body["usuariosActivos"] == 2
        assert body["habitosCreados"] == 1

    def test_400_fechas_invalidas_o_invertidas(self, admin_client):
        assert admin_client.get("/v1/admin/reportes/uso?desde=ayer").status_code == 400
        assert admin_client.get(
            "/v1/admin/reportes/uso?desde=2026-07-20&hasta=2026-07-01"
        ).status_code == 400


class TestModeracion:
    @pytest.fixture
    def reporte(self, auth_client, usuario):
        otro = Usuario.objects.create_user(
            email="reportante@example.com", password="S3gura-123", nombre="Reportante"
        )
        post = auth_client.post(
            "/v1/comunidad/publicaciones", {"contenido": "contenido dudoso"},
            format="json",
        ).json()
        return _cliente_de(otro).post(
            f"/v1/comunidad/publicaciones/{post['id']}/reportes",
            {"motivo": "spam", "detalle": "parece spam"}, format="json",
        ).json()

    def test_listado_sin_identidad_del_reportante(self, admin_client, reporte):
        listado = admin_client.get("/v1/admin/moderacion/reportes").json()
        assert len(listado) == 1
        assert set(listado[0].keys()) == {
            "id", "publicacionId", "motivo", "detalle", "estado", "creadoEn",
        }  # sin reportante

    def test_resolver_ocultar(self, admin_client, auth_client, reporte):
        resp = admin_client.patch(
            f"/v1/admin/moderacion/reportes/{reporte['id']}",
            {"resolucion": "ocultar", "razon": "confirmado"}, format="json",
        )
        assert resp.status_code == 204
        # la publicación deja de ser visible para la comunidad
        assert auth_client.get(
            f"/v1/comunidad/publicaciones/{reporte['publicacionId']}"
        ).status_code == 404
        listado = admin_client.get(
            "/v1/admin/moderacion/reportes?estado=resuelto"
        ).json()
        assert [r["id"] for r in listado] == [reporte["id"]]

    def test_resolver_aprobar_descarta_y_mantiene_visible(
        self, admin_client, auth_client, reporte
    ):
        admin_client.patch(
            f"/v1/admin/moderacion/reportes/{reporte['id']}",
            {"resolucion": "aprobar", "razon": "sin infracción"}, format="json",
        )
        assert auth_client.get(
            f"/v1/comunidad/publicaciones/{reporte['publicacionId']}"
        ).status_code == 200
        assert admin_client.get(
            "/v1/admin/moderacion/reportes?estado=descartado"
        ).json()[0]["id"] == reporte["id"]

    def test_409_resolver_dos_veces_quirk_de_go(self, admin_client, reporte):
        url = f"/v1/admin/moderacion/reportes/{reporte['id']}"
        admin_client.patch(url, {"resolucion": "aprobar", "razon": "ok"}, format="json")
        resp = admin_client.patch(url, {"resolucion": "ocultar", "razon": "x"},
                                  format="json")
        assert resp.status_code == 409
        # Go reutiliza ErrReporteDuplicado: mensaje/código de "ya reportada"
        assert resp.json()["codigo"] == "report_already_exists"

    def test_400_resolucion_invalida(self, admin_client, reporte):
        resp = admin_client.patch(
            f"/v1/admin/moderacion/reportes/{reporte['id']}",
            {"resolucion": "borrar", "razon": "x"}, format="json",
        )
        assert resp.status_code == 400


class TestInspiracionAdmin:
    def test_listado_incluye_no_publicados_y_campo_publicado(self, admin_client):
        from apps.inspiracion.models import ContenidoInspiracion

        oculto = ContenidoInspiracion.objects.first()
        ContenidoInspiracion.objects.filter(id=oculto.id).update(publicado=False)
        listado = admin_client.get("/v1/admin/inspiracion?limit=50").json()
        assert len(listado) == 21  # seed completo, incluido el no publicado
        assert all("publicado" in c for c in listado)
        ocultos = admin_client.get("/v1/admin/inspiracion?publicado=false").json()
        assert [c["id"] for c in ocultos] == [str(oculto.id)]

    def test_crear_con_defaults_de_go(self, admin_client):
        resp = admin_client.post(
            "/v1/admin/inspiracion",
            {"tipo": "articulo", "titulo": "Nuevo", "resumen": "Un resumen",
             "url": "https://example.com/a", "autor": "Autora"},
            format="json",
        )
        assert resp.status_code == 201
        body = resp.json()
        assert body["publicado"] is True  # default de Go
        assert body["destacado"] is False
        assert "imagenUrl" not in body  # omitempty

    def test_400_campo_requerido_ausente(self, admin_client):
        resp = admin_client.post(
            "/v1/admin/inspiracion",
            {"tipo": "articulo", "titulo": "Sin resumen"}, format="json",
        )
        assert resp.status_code == 400

    def test_patch_merge_parcial(self, admin_client):
        from apps.inspiracion.models import ContenidoInspiracion

        contenido = ContenidoInspiracion.objects.first()
        resp = admin_client.patch(
            f"/v1/admin/inspiracion/{contenido.id}",
            {"publicado": False}, format="json",
        )
        assert resp.status_code == 200
        body = resp.json()
        assert body["publicado"] is False
        assert body["titulo"] == contenido.titulo  # lo no enviado se conserva

    def test_delete_y_404(self, admin_client):
        from apps.inspiracion.models import ContenidoInspiracion

        contenido = ContenidoInspiracion.objects.first()
        assert admin_client.delete(
            f"/v1/admin/inspiracion/{contenido.id}"
        ).status_code == 204
        resp = admin_client.get(f"/v1/admin/inspiracion/{contenido.id}")
        assert resp.status_code == 404
        assert resp.json() == {"mensaje": "contenido no encontrado", "codigo": "not_found"}


class TestSolicitudes:
    def test_ciclo_completo_aprobar(self, auth_client, admin_client, admin, usuario):
        resp = auth_client.post(
            "/v1/solicitudes-administrador", {"motivo": "  quiero ayudar  "},
            format="json",
        )
        assert resp.status_code == 201
        creada = resp.json()
        assert creada["estado"] == "pendiente"
        assert creada["motivo"] == "quiero ayudar"  # recortado
        assert "razonDecision" not in creada  # omitempty
        assert "revisadoEn" not in creada

        # el propio usuario la consulta
        propia = auth_client.get("/v1/solicitudes-administrador/me").json()
        assert propia["id"] == creada["id"]
        assert propia["usuarioEmail"] == "test@habitbuilder.dev"

        # duplicada mientras está pendiente → 409
        resp = auth_client.post(
            "/v1/solicitudes-administrador", {"motivo": "otra vez"}, format="json"
        )
        assert resp.status_code == 409
        assert resp.json() == {
            "mensaje": "la solicitud administrativa ya fue resuelta o esta pendiente",
            "codigo": "request_conflict",
        }

        # el admin la aprueba: promueve el rol y audita en la misma transacción
        resp = admin_client.patch(
            f"/v1/admin/solicitudes-administrador/{creada['id']}",
            {"decision": "aprobar", "razon": "aprobada por mérito"}, format="json",
        )
        assert resp.status_code == 200
        body = resp.json()
        assert body["estado"] == "aprobada"
        assert body["razonDecision"] == "aprobada por mérito"
        assert body["revisadoEn"] is not None
        usuario.refresh_from_db()
        assert usuario.rol == "admin"
        assert AuditoriaAdministrativa.objects.filter(
            objetivo=usuario, accion="aprobar_solicitud_admin"
        ).exists()

        # resolverla de nuevo → 409
        resp = admin_client.patch(
            f"/v1/admin/solicitudes-administrador/{creada['id']}",
            {"decision": "rechazar", "razon": "x"}, format="json",
        )
        assert resp.status_code == 409

    def test_rechazar_no_promueve(self, auth_client, admin_client, usuario):
        creada = auth_client.post(
            "/v1/solicitudes-administrador", {"motivo": "quiero"}, format="json"
        ).json()
        resp = admin_client.patch(
            f"/v1/admin/solicitudes-administrador/{creada['id']}",
            {"decision": "rechazar", "razon": "sin justificación"}, format="json",
        )
        assert resp.json()["estado"] == "rechazada"
        usuario.refresh_from_db()
        assert usuario.rol == "regular"
        # tras el rechazo puede volver a solicitar
        assert auth_client.post(
            "/v1/solicitudes-administrador", {"motivo": "de nuevo"}, format="json"
        ).status_code == 201

    def test_404_sin_solicitud_propia(self, auth_client):
        resp = auth_client.get("/v1/solicitudes-administrador/me")
        assert resp.status_code == 404
        assert resp.json() == {
            "mensaje": "solicitud administrativa no encontrada", "codigo": "not_found",
        }

    def test_listado_admin_con_filtro(self, auth_client, admin_client):
        auth_client.post("/v1/solicitudes-administrador", {"motivo": "m"}, format="json")
        assert len(admin_client.get(
            "/v1/admin/solicitudes-administrador?estado=pendiente"
        ).json()) == 1
        assert admin_client.get(
            "/v1/admin/solicitudes-administrador?estado=aceptada"
        ).status_code == 400

    @pytest.mark.parametrize("motivo", ["", "   ", "x" * 501])
    def test_400_motivo_invalido(self, auth_client, motivo):
        resp = auth_client.post(
            "/v1/solicitudes-administrador", {"motivo": motivo}, format="json"
        )
        assert resp.status_code == 400

    def test_404_resolver_inexistente(self, admin_client):
        resp = admin_client.patch(
            f"/v1/admin/solicitudes-administrador/{uuid.uuid4()}",
            {"decision": "aprobar", "razon": "x"}, format="json",
        )
        assert resp.status_code == 404
