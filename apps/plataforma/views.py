"""Endpoints transversales de plataforma."""
from django.db import connection
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework.views import APIView


class HealthView(APIView):
    """GET /health — misma semántica que el health check del backend Go:
    200 con estado de la base de datos."""

    authentication_classes: list = []
    permission_classes = [AllowAny]

    def get(self, request):
        try:
            with connection.cursor() as cursor:
                cursor.execute("SELECT 1")
            db_status = "ok"
        except Exception:
            db_status = "error"
        code = 200 if db_status == "ok" else 503
        return Response({"status": "ok" if code == 200 else "degraded",
                         "database": db_status}, status=code)
