"""Modelos del dominio 'comunidad' (migraciones Go 0011 y 0013).

Los CHECK con char_length(trim(...)) se replican con los transforms
registrados en apps.plataforma.db (columna__trim__length__range).
"""
import uuid

from django.conf import settings
from django.db import models

import apps.plataforma.db  # noqa: F401 - registra transforms trim/length


class PublicacionComunidad(models.Model):
    """Tabla `publicaciones_comunidad` (0011 + estado_moderacion de 0013)."""

    class EstadoModeracion(models.TextChoices):
        VISIBLE = "visible"
        EN_REVISION = "en_revision"
        OCULTO = "oculto"
        ELIMINADO = "eliminado"

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    usuario = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.PROTECT,
        db_column="usuario_id", related_name="publicaciones",
    )
    contenido = models.TextField()
    habito = models.ForeignKey(
        "habitosymetas.Habito", on_delete=models.PROTECT, null=True,
        db_column="habito_id", related_name="publicaciones",
    )
    estado_moderacion = models.TextField(
        choices=EstadoModeracion.choices, default=EstadoModeracion.VISIBLE
    )
    creado_en = models.DateTimeField(auto_now_add=True)
    actualizado_en = models.DateTimeField(auto_now=True)
    eliminado_en = models.DateTimeField(null=True)

    class Meta:
        db_table = "publicaciones_comunidad"
        constraints = [
            # char_length(trim(contenido)) BETWEEN 1 AND 1000
            models.CheckConstraint(
                condition=models.Q(contenido__trim__length__range=(1, 1000)),
                name="publicaciones_comunidad_contenido_check",
            ),
        ]
        indexes = [
            models.Index(
                fields=["-creado_en"],
                condition=models.Q(eliminado_en__isnull=True),
                name="publicaciones_feed_idx",
            ),
            models.Index(
                fields=["usuario", "-creado_en"],
                name="publicaciones_usuario_idx",
            ),
            models.Index(
                fields=["estado_moderacion", "-creado_en"],
                condition=models.Q(eliminado_en__isnull=True),
                name="publicaciones_visibilidad_idx",
            ),
        ]


class ComentarioComunidad(models.Model):
    """Tabla `comentarios_comunidad` (0011)."""

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    publicacion = models.ForeignKey(
        PublicacionComunidad, on_delete=models.PROTECT,
        db_column="publicacion_id", related_name="comentarios",
    )
    usuario = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.PROTECT,
        db_column="usuario_id", related_name="comentarios",
    )
    contenido = models.TextField()
    creado_en = models.DateTimeField(auto_now_add=True)
    eliminado_en = models.DateTimeField(null=True)

    class Meta:
        db_table = "comentarios_comunidad"
        constraints = [
            models.CheckConstraint(
                condition=models.Q(contenido__trim__length__range=(1, 500)),
                name="comentarios_comunidad_contenido_check",
            ),
        ]
        indexes = [
            models.Index(
                fields=["publicacion", "creado_en"],
                condition=models.Q(eliminado_en__isnull=True),
                name="comentarios_publicacion_idx",
            ),
        ]


class ReaccionComunidad(models.Model):
    """Tabla `reacciones_comunidad`: PK compuesta (publicacion, usuario)."""

    pk = models.CompositePrimaryKey("publicacion", "usuario")
    publicacion = models.ForeignKey(
        PublicacionComunidad, on_delete=models.PROTECT,
        db_column="publicacion_id", related_name="reacciones",
    )
    usuario = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.PROTECT,
        db_column="usuario_id", related_name="reacciones",
    )
    creado_en = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "reacciones_comunidad"


class ReporteComunidad(models.Model):
    """Tabla `reportes_comunidad` (0013)."""

    class Motivo(models.TextChoices):
        SPAM = "spam"
        ACOSO = "acoso"
        INAPROPIADO = "inapropiado"
        OTRO = "otro"

    class Estado(models.TextChoices):
        PENDIENTE = "pendiente"
        RESUELTO = "resuelto"
        DESCARTADO = "descartado"

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    publicacion = models.ForeignKey(
        PublicacionComunidad, on_delete=models.PROTECT,
        db_column="publicacion_id", related_name="reportes",
    )
    reportante = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.PROTECT,
        db_column="reportante_id", related_name="reportes_enviados",
    )
    motivo = models.TextField(choices=Motivo.choices)
    detalle = models.TextField(null=True)
    estado = models.TextField(choices=Estado.choices, default=Estado.PENDIENTE)
    creado_en = models.DateTimeField(auto_now_add=True)
    resuelto_en = models.DateTimeField(null=True)
    resuelto_por = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.PROTECT, null=True,
        db_column="resuelto_por", related_name="reportes_resueltos",
    )

    class Meta:
        db_table = "reportes_comunidad"
        constraints = [
            # Un usuario reporta una publicación a lo sumo una vez
            models.UniqueConstraint(
                fields=["publicacion", "reportante"],
                name="reportes_comunidad_unico_por_usuario",
            ),
            models.CheckConstraint(
                condition=models.Q(detalle__isnull=True)
                | models.Q(detalle__length__lte=500),
                name="reportes_comunidad_detalle_limite",
            ),
        ]
        indexes = [
            models.Index(fields=["estado", "creado_en"], name="reportes_estado_idx"),
        ]
