"""Vistas DRF de 'comunidad'."""
from rest_framework import status
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.plataforma.api.exceptions import ContractError

from . import services
from .serializers import comentario_response, publicacion_response, reporte_response


def _cuerpo(request) -> dict:
    if not isinstance(request.data, dict):
        raise ContractError(
            "cuerpo de la solicitud invalido", status_code=400, codigo="invalid_request"
        )
    return request.data


class PublicacionesView(APIView):
    def get(self, request):
        feed = services.listar_feed(
            request.user,
            limit_raw=request.query_params.get("limit"),
            offset_raw=request.query_params.get("offset"),
        )
        return Response([publicacion_response(p) for p in feed])

    def post(self, request):
        datos = _cuerpo(request)
        publicacion = services.crear_publicacion(
            request.user,
            contenido=datos.get("contenido"),
            habito_id_raw=datos.get("habitoId"),
        )
        return Response(publicacion_response(publicacion), status=status.HTTP_201_CREATED)


class PublicacionDetalleView(APIView):
    def get(self, request, id):
        return Response(
            publicacion_response(services.obtener_publicacion(request.user, id))
        )

    def patch(self, request, id):
        datos = _cuerpo(request)
        publicacion = services.editar_publicacion(
            request.user, id, contenido=datos.get("contenido")
        )
        return Response(publicacion_response(publicacion))

    def delete(self, request, id):
        services.eliminar_publicacion(request.user, id)
        return Response(status=status.HTTP_204_NO_CONTENT)


class ComentariosView(APIView):
    def get(self, request, id):
        comentarios = services.listar_comentarios(request.user, id)
        return Response([comentario_response(c) for c in comentarios])

    def post(self, request, id):
        datos = _cuerpo(request)
        comentario = services.crear_comentario(
            request.user, id, contenido=datos.get("contenido")
        )
        return Response(
            comentario_response(comentario, recien_creado=True),
            status=status.HTTP_201_CREATED,
        )


class ComentarioDetalleView(APIView):
    def delete(self, request, id):
        services.eliminar_comentario(request.user, id)
        return Response(status=status.HTTP_204_NO_CONTENT)


class ReaccionView(APIView):
    def post(self, request, id):
        services.reaccionar(request.user, id)
        return Response(status=status.HTTP_204_NO_CONTENT)

    def delete(self, request, id):
        services.quitar_reaccion(request.user, id)
        return Response(status=status.HTTP_204_NO_CONTENT)


class ReportesView(APIView):
    def post(self, request, id):
        datos = _cuerpo(request)
        reporte = services.crear_reporte(
            request.user, id,
            motivo=datos.get("motivo"),
            detalle=datos.get("detalle"),
        )
        return Response(reporte_response(reporte), status=status.HTTP_201_CREATED)
