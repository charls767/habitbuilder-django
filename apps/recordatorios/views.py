"""Vistas DRF de 'recordatorios'. Las mismas vistas sirven las rutas en
español (/v1/...) y los alias móviles en inglés (/habits/, /reminders/)."""
from rest_framework import status
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.plataforma.api.exceptions import ContractError

from . import services
from .serializers import recordatorio_response

MENSAJE_CUERPO_INVALIDO = "cuerpo de la solicitud invalido"


def _cuerpo(request) -> dict:
    if not isinstance(request.data, dict):
        raise ContractError(
            MENSAJE_CUERPO_INVALIDO, status_code=400,
            codigo=services.CODIGO_VALIDACION,
        )
    return request.data


class RecordatoriosDeHabitoView(APIView):
    def get(self, request, id):
        recs = services.listar_recordatorios(request.user, id)
        return Response([recordatorio_response(r) for r in recs])

    def post(self, request, id):
        datos = _cuerpo(request)
        rec = services.crear_recordatorio(
            request.user, id,
            mensaje=datos.get("mensaje"),
            hora=datos.get("hora"),
            dias_semana=datos.get("diasSemana"),
            activo=datos.get("activo"),
        )
        return Response(recordatorio_response(rec), status=status.HTTP_201_CREATED)


class RecordatorioDetalleView(APIView):
    def patch(self, request, id):
        datos = _cuerpo(request)
        rec = services.editar_recordatorio(
            request.user, id,
            mensaje=datos.get("mensaje"),
            hora=datos.get("hora"),
            dias_semana=datos.get("diasSemana"),
            activo=datos.get("activo"),
        )
        return Response(recordatorio_response(rec))

    def delete(self, request, id):
        services.eliminar_recordatorio(request.user, id)
        return Response(status=status.HTTP_204_NO_CONTENT)
