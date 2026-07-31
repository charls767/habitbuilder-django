"""Modelos del dominio 'inspiración' (migración Go 0012).

El seed 0015 (catálogo inicial) se replica como data migration de Django.
"""
import uuid

from django.db import models

import apps.plataforma.db  # noqa: F401 - registra transforms trim/length


class ContenidoInspiracion(models.Model):
    """Tabla `contenidos_inspiracion`."""

    class Tipo(models.TextChoices):
        ARTICULO = "articulo"
        VIDEO = "video"
        AUDIO = "audio"

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    tipo = models.TextField(choices=Tipo.choices)
    titulo = models.TextField()
    resumen = models.TextField()
    url = models.TextField()
    imagen_url = models.TextField(null=True)
    autor = models.TextField()
    destacado = models.BooleanField(default=False)
    publicado = models.BooleanField(default=True)
    creado_en = models.DateTimeField(auto_now_add=True)
    actualizado_en = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = "contenidos_inspiracion"
        constraints = [
            models.CheckConstraint(
                condition=models.Q(titulo__trim__length__range=(1, 180)),
                name="contenidos_inspiracion_titulo_check",
            ),
            models.CheckConstraint(
                condition=models.Q(resumen__trim__length__range=(1, 500)),
                name="contenidos_inspiracion_resumen_check",
            ),
            models.CheckConstraint(
                condition=models.Q(url__trim__length__range=(1, 2048)),
                name="contenidos_inspiracion_url_check",
            ),
            models.CheckConstraint(
                condition=models.Q(autor__trim__length__range=(1, 180)),
                name="contenidos_inspiracion_autor_check",
            ),
        ]
        indexes = [
            models.Index(
                fields=["publicado", "-destacado", "-creado_en"],
                name="inspiracion_listado_idx",
            ),
            models.Index(
                fields=["tipo", "publicado", "-creado_en"],
                name="inspiracion_tipo_idx",
            ),
        ]
