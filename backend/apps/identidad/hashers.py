"""Hasher Argon2id con los parámetros exactos del backend Go.

Go usa el perfil RFC 9106 "less memory" (argon2_hasher.go):
    t=3, m=64 MiB, p=4, keyLen=32, salt=16
elegido para no exceder la memoria del tier gratuito de Cloud Run. Django
por defecto usa t=2/m=100 MiB/p=8; este subclass iguala los costes para
mantener el mismo perfil de recursos y latencia (NFR <2s).

Formato: Go guarda el PHC crudo `$argon2id$v=19$m=65536,t=3,p=4$salt$hash`;
Django guarda lo mismo con el prefijo `argon2$`. La verificación de hashes
heredados de Go vive en Usuario.check_password (models.py).
"""
from django.contrib.auth.hashers import Argon2PasswordHasher


class HabitBuilderArgon2Hasher(Argon2PasswordHasher):
    time_cost = 3
    memory_cost = 64 * 1024  # KiB
    parallelism = 4
