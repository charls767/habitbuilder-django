"""Modelos del dominio 'recordatorios' (migración Go 0008)."""
import uuid

from django.conf import settings
from django.contrib.postgres.fields import ArrayField
from django.db import models


class Recordatorio(models.Model):
    """Tabla `recordatorios`."""

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    usuario = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.PROTECT,
        db_column="usuario_id", related_name="recordatorios",
    )
    habito = models.ForeignKey(
        "habitosymetas.Habito", on_delete=models.PROTECT,
        db_column="habito_id", related_name="recordatorios",
    )
    mensaje = models.TextField()
    hora = models.TimeField()
    dias_semana = ArrayField(models.SmallIntegerField())
    activo = models.BooleanField()
    creado_en = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "recordatorios"
