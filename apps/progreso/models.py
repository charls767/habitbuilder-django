"""Modelos del dominio 'progreso' (migración Go 0010)."""
from django.conf import settings
from django.db import models


class RachaHabito(models.Model):
    """Tabla `rachas_habito`: PK compuesta (habito_id, usuario_id), igual
    que en Go (requiere Django >= 5.2)."""

    pk = models.CompositePrimaryKey("habito", "usuario")
    habito = models.ForeignKey(
        "habitosymetas.Habito", on_delete=models.PROTECT,
        db_column="habito_id", related_name="rachas",
    )
    usuario = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.PROTECT,
        db_column="usuario_id", related_name="rachas",
    )
    racha_actual = models.IntegerField(default=0)
    racha_mas_larga = models.IntegerField(default=0)
    actualizado_en = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = "rachas_habito"
        constraints = [
            models.CheckConstraint(
                condition=models.Q(racha_actual__gte=0) & models.Q(racha_mas_larga__gte=0),
                name="rachas_habito_contadores_no_negativos",
            ),
            models.CheckConstraint(
                condition=models.Q(racha_actual__lte=models.F("racha_mas_larga")),
                name="rachas_habito_actual_no_supera_mas_larga",
            ),
        ]
