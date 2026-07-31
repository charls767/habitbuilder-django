"""Vistas DRF del catálogo público de 'inspiración'."""
from rest_framework.response import Response
from rest_framework.views import APIView

from . import services
from .serializers import contenido_response


class InspiracionView(APIView):
    def get(self, request):
        contenidos = services.listar_contenidos(
            tipo_raw=request.query_params.get("tipo"),
            limit_raw=request.query_params.get("limit"),
            offset_raw=request.query_params.get("offset"),
        )
        return Response([contenido_response(c) for c in contenidos])


class InspiracionDetalleView(APIView):
    def get(self, request, id):
        return Response(contenido_response(services.obtener_contenido(id)))
