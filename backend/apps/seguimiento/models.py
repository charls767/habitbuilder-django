"""Modelos del dominio 'seguimiento' (migración Go 0009)."""
import uuid

from django.conf import settings
from django.db import models


class RegistroHabito(models.Model):
    """Tabla `registros_habito`: cumplimiento diario por hábito."""

    class Estado(models.TextChoices):
        HECHO = "hecho"
        PARCIAL = "parcial"
        OMITIDO = "omitido"

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    usuario = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.PROTECT,
        db_column="usuario_id", related_name="registros",
    )
    habito = models.ForeignKey(
        "habitosymetas.Habito", on_delete=models.PROTECT,
        db_column="habito_id", related_name="registros",
    )
    fecha_local = models.DateField()
    estado = models.TextField(choices=Estado.choices)
    nota = models.TextField(null=True)
    creado_en = models.DateTimeField(auto_now_add=True)
    actualizado_en = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = "registros_habito"
        constraints = [
            # Un registro por hábito/usuario/día (clave natural, permite upsert)
            models.UniqueConstraint(
                fields=["habito", "usuario", "fecha_local"],
                name="registros_habito_clave_natural",
            ),
            models.CheckConstraint(
                condition=models.Q(estado__in=["hecho", "parcial", "omitido"]),
                name="registros_habito_estado_check",
            ),
        ]
