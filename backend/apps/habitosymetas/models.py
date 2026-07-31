"""Modelos del dominio 'hábitos y metas'.

Espejo de las migraciones Go 0005 (habitos), 0006 (habito_pausas) y
0007 (metas + FK habitos.meta_id).
"""
import uuid

from django.conf import settings
from django.contrib.postgres.fields import ArrayField
from django.db import models


class MetaPersonal(models.Model):
    """Tabla `metas` (migración 0007).

    Se llama MetaPersonal (no Meta) porque `Meta` colisionaría con la clase
    de opciones interna de los modelos Django. El contrato no cambia: la
    tabla sigue siendo `metas` y los payloads los definen los serializers.
    """

    class Estado(models.TextChoices):
        EN_PROGRESO = "en_progreso"
        LOGRADA = "lograda"
        PAUSADA = "pausada"
        CANCELADA = "cancelada"

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    usuario = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.PROTECT,
        db_column="usuario_id", related_name="metas",
    )
    descripcion = models.TextField()
    fecha_objetivo = models.DateField()
    estado = models.TextField(choices=Estado.choices, default=Estado.EN_PROGRESO)
    creado_en = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "metas"
        constraints = [
            models.CheckConstraint(
                condition=models.Q(
                    estado__in=["en_progreso", "lograda", "pausada", "cancelada"]
                ),
                name="metas_estado_check",
            ),
        ]


class Habito(models.Model):
    """Tabla `habitos` (migración 0005)."""

    class FrecuenciaTipo(models.TextChoices):
        DIARIA = "diaria"
        DIAS_ESPECIFICOS = "dias_especificos"
        N_VECES_POR_PERIODO = "n_veces_por_periodo"

    class Estado(models.TextChoices):
        ACTIVO = "activo"
        PAUSADO = "pausado"
        COMPLETADO = "completado"
        ELIMINADO = "eliminado"

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    usuario = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.PROTECT,
        db_column="usuario_id", related_name="habitos",
    )
    nombre = models.TextField()
    descripcion = models.TextField(null=True)
    fecha_inicio = models.DateField()
    frecuencia_tipo = models.TextField(choices=FrecuenciaTipo.choices)
    frecuencia_dias_semana = ArrayField(models.SmallIntegerField(), null=True)
    frecuencia_veces = models.IntegerField(null=True)
    frecuencia_periodo = models.TextField(null=True)
    categoria = models.TextField(null=True)
    meta = models.ForeignKey(
        MetaPersonal, on_delete=models.SET_NULL, null=True,
        db_column="meta_id", related_name="habitos",
    )
    estado = models.TextField(choices=Estado.choices, default=Estado.ACTIVO)
    eliminado_en = models.DateTimeField(null=True)
    creado_en = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "habitos"
        constraints = [
            # frecuencia 'dias_especificos' exige dias_semana
            models.CheckConstraint(
                condition=~models.Q(frecuencia_tipo="dias_especificos")
                | models.Q(frecuencia_dias_semana__isnull=False),
                name="frecuencia_dias_especificos_requiere_dias",
            ),
            # frecuencia 'n_veces_por_periodo' exige veces y periodo
            models.CheckConstraint(
                condition=~models.Q(frecuencia_tipo="n_veces_por_periodo")
                | (
                    models.Q(frecuencia_veces__isnull=False)
                    & models.Q(frecuencia_periodo__isnull=False)
                ),
                name="frecuencia_n_veces_requiere_campos",
            ),
        ]
        indexes = [
            models.Index(
                fields=["usuario"],
                condition=models.Q(eliminado_en__isnull=True),
                name="habitos_usuario_id_idx",
            ),
            models.Index(
                fields=["meta"],
                condition=models.Q(meta__isnull=False),
                name="habitos_meta_id_idx",
            ),
        ]


class HabitoPausa(models.Model):
    """Tabla `habito_pausas` (migración 0006)."""

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    habito = models.ForeignKey(
        Habito, on_delete=models.PROTECT, db_column="habito_id", related_name="pausas"
    )
    inicio = models.DateField()
    fin = models.DateField(null=True)
    creado_en = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "habito_pausas"
