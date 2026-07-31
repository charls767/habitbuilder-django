"""Vistas DRF de 'seguimiento'."""
from rest_framework import status
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.plataforma.api.exceptions import ContractError

from . import services
from .serializers import registro_response


class RegistrosDeHabitoView(APIView):
    def get(self, request, id):
        registros = services.listar_registros(
            request.user, id,
            desde_raw=request.query_params.get("desde"),
            hasta_raw=request.query_params.get("hasta"),
        )
        return Response([registro_response(r) for r in registros])

    def post(self, request, id):
        if not isinstance(request.data, dict):
            raise ContractError(
                "cuerpo de la solicitud invalido", status_code=400,
                codigo=services.CODIGO_VALIDACION,
            )
        registro, creado = services.registrar_completitud(
            request.user, id,
            fecha_local_raw=request.data.get("fechaLocal"),
            estado=request.data.get("estado"),
            nota=request.data.get("nota"),
        )
        codigo = status.HTTP_201_CREATED if creado else status.HTTP_200_OK
        return Response(registro_response(registro), status=codigo)
