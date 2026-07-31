"""Alias móviles en inglés (x-alias-of en docs/openapi.yaml), montados en la
RAÍZ (sin /v1): /habits/{habitId}/reminders y /reminders/{reminderId}."""
from django.urls import path

from . import views

urlpatterns = [
    path(
        "habits/<str:id>/reminders",
        views.RecordatoriosDeHabitoView.as_view(),
        name="habit-reminders",
    ),
    path(
        "reminders/<str:id>",
        views.RecordatorioDetalleView.as_view(),
        name="reminder-detail",
    ),
]
