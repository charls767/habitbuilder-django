"""Transforms de BD compartidos.

Las migraciones Go usan CHECKs del estilo:
    char_length(trim(columna)) BETWEEN 1 AND 500

Registrar Length y Trim como transforms permite expresarlos en Django como:
    Q(columna__trim__length__range=(1, 500))

Este módulo debe importarse desde cada models.py que declare esos CHECKs
(la importación registra los lookups antes de que se evalúen los constraints).
"""
from django.db import models
from django.db.models.functions import Length, Trim

models.TextField.register_lookup(Length)
models.TextField.register_lookup(Trim)
