"""Vistas DRF de 'hábitos y metas' (espejo de http_handlers_habito/meta.go)."""
from rest_framework import status
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.plataforma.api.exceptions import ContractError

from . import services
from .serializers import habito_response, meta_response

MENSAJE_CUERPO_INVALIDO_HM = "cuerpo de la solicitud invalido"  # sin tilde en Go


def _cuerpo(request) -> dict:
    if not isinstance(request.data, dict):
        raise ContractError(MENSAJE_CUERPO_INVALIDO_HM, status_code=400)
    return request.data


class HabitosView(APIView):
    def get(self, request):
        habitos = services.listar_habitos(request.user)
        return Response([habito_response(h) for h in habitos])

    def post(self, request):
        datos = _cuerpo(request)
        fecha_inicio = services.parse_fecha(
            datos.get("fechaInicio"), "fecha de inicio invalida"
        )
        habito = services.crear_habito(
            request.user,
            nombre=datos.get("nombre"),
            descripcion=datos.get("descripcion"),
            fecha_inicio=fecha_inicio,
            frecuencia=datos.get("frecuencia"),
            categoria=datos.get("categoria"),
            meta_id=datos.get("metaId"),
        )
        return Response(habito_response(habito), status=status.HTTP_201_CREATED)


class HabitoDetalleView(APIView):
    def get(self, request, id):
        return Response(habito_response(services.obtener_habito(request.user, id)))

    def patch(self, request, id):
        habito = services.editar_habito(request.user, id, _cuerpo(request))
        return Response(habito_response(habito))

    def delete(self, request, id):
        habito, impacto = services.eliminar_habito(request.user, id)
        return Response({"habito": habito_response(habito), "impacto": impacto})


class PausarHabitoView(APIView):
    def post(self, request, id):
        datos = _cuerpo(request)
        inicio = services.parse_fecha(datos.get("inicio"), "inicio invalido")
        fin = None
        if datos.get("fin") is not None:
            fin = services.parse_fecha(datos.get("fin"), "fin invalido")
        habito = services.pausar_habito(request.user, id, inicio=inicio, fin=fin)
        return Response(habito_response(habito))


class ReanudarHabitoView(APIView):
    def post(self, request, id):
        return Response(habito_response(services.reanudar_habito(request.user, id)))


class CompletarHabitoView(APIView):
    def post(self, request, id):
        return Response(habito_response(services.completar_habito(request.user, id)))


class MetasView(APIView):
    def get(self, request):
        return Response([meta_response(m) for m in services.listar_metas(request.user)])

    def post(self, request):
        datos = _cuerpo(request)
        fecha = services.parse_fecha(datos.get("fechaObjetivo"), "fecha objetivo invalida")
        meta = services.crear_meta(
            request.user, descripcion=datos.get("descripcion"), fecha_objetivo=fecha
        )
        return Response(meta_response(meta), status=status.HTTP_201_CREATED)


class MetaDetalleView(APIView):
    def get(self, request, id):
        return Response(meta_response(services.obtener_meta(request.user, id)))

    def patch(self, request, id):
        datos = _cuerpo(request)
        fecha = None
        if "fechaObjetivo" in datos:
            fecha = services.parse_fecha(datos["fechaObjetivo"], "fecha objetivo invalida")
        meta = services.editar_meta(
            request.user, id, descripcion=datos.get("descripcion"), fecha_objetivo=fecha
        )
        return Response(meta_response(meta))


class EstadoMetaView(APIView):
    def patch(self, request, id):
        datos = _cuerpo(request)
        meta = services.actualizar_estado_meta(request.user, id, datos.get("estado"))
        return Response(meta_response(meta))


class VincularHabitosView(APIView):
    def post(self, request, id):
        datos = _cuerpo(request)
        meta = services.vincular_habitos(request.user, id, datos.get("habitoIds"))
        return Response(meta_response(meta))


class DesvincularHabitoView(APIView):
    def delete(self, request, id, habitoId):  # noqa: N803 (nombre del contrato)
        services.desvincular_habito(request.user, id, habitoId)
        return Response(status=status.HTTP_204_NO_CONTENT)
