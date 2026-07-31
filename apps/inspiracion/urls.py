"""Rutas del catálogo público de 'inspiración' (montadas bajo /v1/)."""
from django.urls import path

from . import views

urlpatterns = [
    path("inspiracion", views.InspiracionView.as_view(), name="inspiracion"),
    path("inspiracion/<str:id>", views.InspiracionDetalleView.as_view(),
         name="inspiracion-detalle"),
]
