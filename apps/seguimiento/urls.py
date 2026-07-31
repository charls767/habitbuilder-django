"""Rutas de 'seguimiento' (montadas bajo /v1/)."""
from django.urls import path

from . import views

urlpatterns = [
    path(
        "habitos/<str:id>/registros",
        views.RegistrosDeHabitoView.as_view(),
        name="habito-registros",
    ),
]
