"""Configuración global de pytest-django."""
import pytest


@pytest.fixture
def usuario(db):
    """Usuario autenticable de prueba, disponible para todas las apps."""
    from apps.identidad.models import Usuario

    return Usuario.objects.create_user(
        email="test@habitbuilder.dev", password="S3gura-123", nombre="Usuario Prueba"
    )


@pytest.fixture
def api_client():
    from rest_framework.test import APIClient

    return APIClient()


@pytest.fixture
def auth_client(api_client, usuario):
    """Cliente con JWT válido, como lo enviaría la app Flutter."""
    from rest_framework_simplejwt.tokens import RefreshToken

    token = RefreshToken.for_user(usuario).access_token
    api_client.credentials(HTTP_AUTHORIZATION=f"Bearer {token}")
    return api_client
