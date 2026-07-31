"""Rutas de 'progreso' y 'estadisticas' (montadas bajo /v1/)."""
from django.urls import path

from . import views

urlpatterns = [
    path(
        "habitos/<str:id>/progreso",
        views.ProgresoHabitoView.as_view(),
        name="habito-progreso",
    ),
    path("progreso", views.ProgresoListaView.as_view(), name="progreso"),
    path("estadisticas", views.EstadisticasView.as_view(), name="estadisticas"),
]
