"""Capa de servicios (casos de uso) del dominio 'plataforma'.

Equivale a la capa 'application' de la arquitectura hexagonal en Go:
las vistas DRF solo validan/serializan y delegan aquí. Ninguna regla
de negocio debe vivir en views.py ni en models.py.
"""
