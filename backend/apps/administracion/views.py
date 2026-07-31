"""Vistas DRF de 'administración'.

Las rutas /v1/admin/* exigen rol admin (EsAdministrador); las de
/v1/solicitudes-administrador solo autenticación.
"""
from rest_framework import status
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.inspiracion import services as inspiracion_services
from apps.inspiracion.serializers import contenido_response
from apps.plataforma.api.exceptions import ContractError

from . import services
from .permissions import EsAdministrador
from .serializers import (
    reporte_moderacion_response,
    solicitud_response,
    usuario_admin_response,
)


class AdminAPIView(APIView):
    permission_classes = [IsAuthenticated, EsAdministrador]


def _cuerpo(request) -> dict:
    if not isinstance(request.data, dict):
        raise ContractError(
            services.MENSAJE_VALIDACION, status_code=400, codigo="invalid_request"
        )
    return request.data


class UsuariosAdminView(AdminAPIView):
    def get(self, request):
        usuarios = services.listar_usuarios(
            estado_raw=request.query_params.get("estado"),
            rol_raw=request.query_params.get("rol"),
            buscar_raw=request.query_params.get("buscar"),
            limit_raw=request.query_params.get("limit"),
            offset_raw=request.query_params.get("offset"),
        )
        return Response([usuario_admin_response(u) for u in usuarios])


class EstadoUsuarioAdminView(AdminAPIView):
    def patch(self, request, id):
        datos = _cuerpo(request)
        services.cambiar_estado_usuario(
            request.user, id, estado=datos.get("estado"), razon=datos.get("razon")
        )
        return Response(status=status.HTTP_204_NO_CONTENT)


class RolUsuarioAdminView(AdminAPIView):
    def patch(self, request, id):
        datos = _cuerpo(request)
        services.cambiar_rol_usuario(
            request.user, id, rol=datos.get("rol"), razon=datos.get("razon")
        )
        return Response(status=status.HTTP_204_NO_CONTENT)


class ReporteUsoAdminView(AdminAPIView):
    def get(self, request):
        return Response(
            services.obtener_reporte_uso(
                desde_raw=request.query_params.get("desde"),
                hasta_raw=request.query_params.get("hasta"),
            )
        )


class ModeracionReportesView(AdminAPIView):
    def get(self, request):
        reportes = services.listar_reportes_moderacion(
            estado_raw=request.query_params.get("estado"),
            limit_raw=request.query_params.get("limit"),
            offset_raw=request.query_params.get("offset"),
        )
        return Response([reporte_moderacion_response(r) for r in reportes])


class ModeracionReporteDetalleView(AdminAPIView):
    def patch(self, request, id):
        datos = _cuerpo(request)
        services.resolver_reporte_moderacion(
            request.user, id,
            resolucion=datos.get("resolucion"),
            razon=datos.get("razon", ""),
        )
        return Response(status=status.HTTP_204_NO_CONTENT)


class InspiracionAdminView(AdminAPIView):
    def get(self, request):
        contenidos = inspiracion_services.listar_contenidos_admin(
            tipo_raw=request.query_params.get("tipo"),
            publicado_raw=request.query_params.get("publicado"),
            destacado_raw=request.query_params.get("destacado"),
            buscar_raw=request.query_params.get("buscar"),
            limit_raw=request.query_params.get("limit"),
            offset_raw=request.query_params.get("offset"),
        )
        return Response([_admin_contenido(c) for c in contenidos])

    def post(self, request):
        contenido = inspiracion_services.crear_contenido_admin(_cuerpo(request))
        return Response(_admin_contenido(contenido), status=status.HTTP_201_CREATED)


class InspiracionAdminDetalleView(AdminAPIView):
    def get(self, request, id):
        return Response(_admin_contenido(inspiracion_services.obtener_contenido_admin(id)))

    def patch(self, request, id):
        contenido = inspiracion_services.actualizar_contenido_admin(id, _cuerpo(request))
        return Response(_admin_contenido(contenido))

    def delete(self, request, id):
        inspiracion_services.eliminar_contenido_admin(id)
        return Response(status=status.HTTP_204_NO_CONTENT)


def _admin_contenido(contenido) -> dict:
    """ContenidoInspiracionAdminResponse: el response público + publicado."""
    return {**contenido_response(contenido), "publicado": contenido.publicado}


class SolicitudesView(APIView):
    """POST /v1/solicitudes-administrador — cualquier autenticado."""

    def post(self, request):
        solicitud = services.crear_solicitud(
            request.user, motivo=_cuerpo(request).get("motivo")
        )
        return Response(
            solicitud_response(solicitud, recien_creada=True),
            status=status.HTTP_201_CREATED,
        )


class SolicitudPropiaView(APIView):
    def get(self, request):
        return Response(solicitud_response(services.obtener_solicitud_propia(request.user)))


class SolicitudesAdminView(AdminAPIView):
    def get(self, request):
        solicitudes = services.listar_solicitudes(
            estado_raw=request.query_params.get("estado"),
            limit_raw=request.query_params.get("limit"),
            offset_raw=request.query_params.get("offset"),
        )
        return Response([solicitud_response(s) for s in solicitudes])


class SolicitudAdminDetalleView(AdminAPIView):
    def patch(self, request, id):
        datos = _cuerpo(request)
        solicitud = services.resolver_solicitud(
            request.user, id,
            decision=datos.get("decision"),
            razon=datos.get("razon"),
        )
        return Response(solicitud_response(solicitud))
