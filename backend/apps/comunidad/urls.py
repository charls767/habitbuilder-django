"""Rutas de 'comunidad' (montadas bajo /v1/)."""
from django.urls import path

from . import views

urlpatterns = [
    path("comunidad/publicaciones", views.PublicacionesView.as_view(),
         name="publicaciones"),
    path("comunidad/publicaciones/<str:id>", views.PublicacionDetalleView.as_view(),
         name="publicacion-detalle"),
    path("comunidad/publicaciones/<str:id>/comentarios", views.ComentariosView.as_view(),
         name="publicacion-comentarios"),
    path("comunidad/publicaciones/<str:id>/reportes", views.ReportesView.as_view(),
         name="publicacion-reportes"),
    path("comunidad/publicaciones/<str:id>/reaccion", views.ReaccionView.as_view(),
         name="publicacion-reaccion"),
    path("comunidad/comentarios/<str:id>", views.ComentarioDetalleView.as_view(),
         name="comentario-detalle"),
]
