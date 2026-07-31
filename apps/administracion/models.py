"""Modelos del dominio 'administración' (migraciones Go 0014 y 0017).

El seed 0016 (promover emails concretos a rol admin) NO se replica: es un
dato de entorno, no de esquema; en Django se hace con
`manage.py createsuperuser` o un comando de gestión.
"""
import uuid

from django.conf import settings
from django.db import models

import apps.plataforma.db  # noqa: F401 - registra transforms trim/length


class AuditoriaAdministrativa(models.Model):
    """Tabla `auditoria_administrativa` (0014): rastro de acciones admin."""

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    actor = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.PROTECT,
        db_column="actor_id", related_name="auditorias_realizadas",
    )
    objetivo = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.PROTECT,
        db_column="objetivo_id", related_name="auditorias_recibidas",
    )
    accion = models.TextField()
    razon = models.TextField()
    creado_en = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "auditoria_administrativa"
        constraints = [
            models.CheckConstraint(
                condition=models.Q(razon__trim__length__range=(1, 500)),
                name="auditoria_administrativa_razon_check",
            ),
        ]
        indexes = [
            models.Index(
                fields=["objetivo", "-creado_en"], name="auditoria_objetivo_idx"
            ),
        ]


class SolicitudAdministrativa(models.Model):
    """Tabla `solicitudes_administrativas` (0017): flujo de acceso admin."""

    class Estado(models.TextChoices):
        PENDIENTE = "pendiente"
        APROBADA = "aprobada"
        RECHAZADA = "rechazada"

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    usuario = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE,  # ON DELETE CASCADE en 0017
        db_column="usuario_id", related_name="solicitudes_admin",
    )
    motivo = models.TextField()
    estado = models.TextField(choices=Estado.choices, default=Estado.PENDIENTE)
    razon_decision = models.TextField(null=True)
    revisado_por = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.PROTECT, null=True,
        db_column="revisado_por", related_name="solicitudes_revisadas",
    )
    creado_en = models.DateTimeField(auto_now_add=True)
    actualizado_en = models.DateTimeField(auto_now=True)
    revisado_en = models.DateTimeField(null=True)

    class Meta:
        db_table = "solicitudes_administrativas"
        constraints = [
            models.CheckConstraint(
                condition=models.Q(motivo__trim__length__range=(1, 500)),
                name="solicitudes_administrativas_motivo_check",
            ),
            models.CheckConstraint(
                condition=models.Q(razon_decision__isnull=True)
                | models.Q(razon_decision__trim__length__range=(1, 500)),
                name="solicitudes_administrativas_razon_check",
            ),
            # A lo sumo UNA solicitud pendiente por usuario (índice parcial 0017)
            models.UniqueConstraint(
                fields=["usuario"],
                condition=models.Q(estado="pendiente"),
                name="solicitudes_admin_pendiente_usuario_unica",
            ),
        ]
        indexes = [
            models.Index(
                fields=["estado", "-creado_en"], name="solicitudes_estado_idx"
            ),
        ]
