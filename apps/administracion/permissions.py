"""Permiso RequireAdmin (espejo del middleware de administracion en Go):
403 {"mensaje": "se requiere rol administrador", "codigo": "forbidden"}
para todo autenticado sin rol admin. El cuerpo lo emite el handler global
al mapear PermissionDenied."""
from rest_framework.permissions import BasePermission


class EsAdministrador(BasePermission):
    def has_permission(self, request, view) -> bool:
        usuario = request.user
        return usuario is not None and getattr(usuario, "rol", None) == "admin"
