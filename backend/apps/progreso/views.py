"""Vistas DRF de 'progreso' y 'estadisticas'."""
from rest_framework.response import Response
from rest_framework.views import APIView

from . import services


class ProgresoHabitoView(APIView):
    def get(self, request, id):
        return Response(
            services.ver_progreso_habito(
                request.user, id,
                periodo_raw=request.query_params.get("periodo"),
                fecha_raw=request.query_params.get("fecha"),
            )
        )


class ProgresoListaView(APIView):
    def get(self, request):
        return Response(
            services.ver_progreso_lista(
                request.user,
                periodo_raw=request.query_params.get("periodo"),
                fecha_raw=request.query_params.get("fecha"),
            )
        )


class EstadisticasView(APIView):
    def get(self, request):
        return Response(
            services.ver_estadisticas(
                request.user,
                periodo_raw=request.query_params.get("periodo"),
                fecha_raw=request.query_params.get("fecha"),
                habito_id_raw=request.query_params.get("habitoId"),
                categoria=request.query_params.get("categoria"),
            )
        )
