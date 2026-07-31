"""Rutas de 'administración' (montadas bajo /v1/): /v1/admin/* y
/v1/solicitudes-administrador*."""
from django.urls import path

from . import views

urlpatterns = [
    path("admin/usuarios", views.UsuariosAdminView.as_view(), name="admin-usuarios"),
    path("admin/usuarios/<str:id>/estado", views.EstadoUsuarioAdminView.as_view(),
         name="admin-usuario-estado"),
    path("admin/usuarios/<str:id>/rol", views.RolUsuarioAdminView.as_view(),
         name="admin-usuario-rol"),
    path("admin/reportes/uso", views.ReporteUsoAdminView.as_view(),
         name="admin-reporte-uso"),
    path("admin/moderacion/reportes", views.ModeracionReportesView.as_view(),
         name="admin-moderacion"),
    path("admin/moderacion/reportes/<str:id>",
         views.ModeracionReporteDetalleView.as_view(),
         name="admin-moderacion-detalle"),
    path("admin/inspiracion", views.InspiracionAdminView.as_view(),
         name="admin-inspiracion"),
    path("admin/inspiracion/<str:id>", views.InspiracionAdminDetalleView.as_view(),
         name="admin-inspiracion-detalle"),
    path("solicitudes-administrador", views.SolicitudesView.as_view(),
         name="solicitudes-admin"),
    path("solicitudes-administrador/me", views.SolicitudPropiaView.as_view(),
         name="solicitud-propia"),
    path("admin/solicitudes-administrador", views.SolicitudesAdminView.as_view(),
         name="admin-solicitudes"),
    path("admin/solicitudes-administrador/<str:id>",
         views.SolicitudAdminDetalleView.as_view(),
         name="admin-solicitud-detalle"),
]
