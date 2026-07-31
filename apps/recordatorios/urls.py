"""Rutas en español de 'recordatorios' (montadas bajo /v1/)."""
from django.urls import path

from . import views

urlpatterns = [
    path(
        "habitos/<str:id>/recordatorios",
        views.RecordatoriosDeHabitoView.as_view(),
        name="habito-recordatorios",
    ),
    path(
        "recordatorios/<str:id>",
        views.RecordatorioDetalleView.as_view(),
        name="recordatorio-detalle",
    ),
]
