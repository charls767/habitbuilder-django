"""Rutas del dominio 'identidad' — exactamente las de docs/openapi.yaml
(montadas bajo /v1/ en config/urls.py)."""
from django.urls import path

from . import views

urlpatterns = [
    path("auth/register", views.RegistroView.as_view(), name="auth-register"),
    path("auth/login", views.LoginView.as_view(), name="auth-login"),
    path("auth/reset/request", views.ResetRequestView.as_view(), name="auth-reset-request"),
    path("auth/reset/confirm", views.ResetConfirmView.as_view(), name="auth-reset-confirm"),
    path("auth/logout", views.LogoutView.as_view(), name="auth-logout"),
    path("usuarios/me", views.PerfilView.as_view(), name="usuarios-me"),
    path("usuarios/me/datos", views.ExportarDatosView.as_view(), name="usuarios-datos"),
]
