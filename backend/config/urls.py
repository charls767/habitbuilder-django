"""Enrutamiento raíz.

Cada app monta sus rutas exactamente como las define docs/openapi.yaml.
El prefijo /v1 vive aquí; dentro de cada apps/<dominio>/urls.py las rutas
se declaran relativas (ej. "habitos/<uuid:id>/pausar").
"""
from django.urls import include, path

urlpatterns = [
    path("", include("apps.plataforma.urls")),        # /health
    path("", include("apps.recordatorios.urls_alias")),  # /habits/*, /reminders/*
    path("v1/", include("apps.identidad.urls")),      # auth/*, usuarios/me
    path("v1/", include("apps.habitosymetas.urls")),  # habitos*, metas*
    path("v1/", include("apps.recordatorios.urls")),
    path("v1/", include("apps.seguimiento.urls")),    # habitos/{id}/registros
    path("v1/", include("apps.progreso.urls")),       # progreso, estadisticas
    path("v1/", include("apps.comunidad.urls")),
    path("v1/", include("apps.inspiracion.urls")),
    path("v1/", include("apps.administracion.urls")), # admin/*, solicitudes-administrador*
]
