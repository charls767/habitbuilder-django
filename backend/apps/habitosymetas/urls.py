"""Rutas de 'hábitos y metas' — docs/openapi.yaml, montadas bajo /v1/.

Se usa <str:> (no <uuid:>) a propósito: un UUID inválido debe responder el
404 JSON del contrato ("habito no encontrado"), no el 404 de Django.
"""
from django.urls import path

from . import views

urlpatterns = [
    path("habitos", views.HabitosView.as_view(), name="habitos"),
    path("habitos/<str:id>", views.HabitoDetalleView.as_view(), name="habito-detalle"),
    path("habitos/<str:id>/pausar", views.PausarHabitoView.as_view(), name="habito-pausar"),
    path("habitos/<str:id>/reanudar", views.ReanudarHabitoView.as_view(), name="habito-reanudar"),
    path("habitos/<str:id>/completar", views.CompletarHabitoView.as_view(),
         name="habito-completar"),
    path("metas", views.MetasView.as_view(), name="metas"),
    path("metas/<str:id>", views.MetaDetalleView.as_view(), name="meta-detalle"),
    path("metas/<str:id>/estado", views.EstadoMetaView.as_view(), name="meta-estado"),
    path("metas/<str:id>/habitos", views.VincularHabitosView.as_view(), name="meta-vincular"),
    path(
        "metas/<str:id>/habitos/<str:habitoId>",
        views.DesvincularHabitoView.as_view(),
        name="meta-desvincular",
    ),
]
