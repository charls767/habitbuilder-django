"""Hasher Argon2id de HabitBuilder.

El coste está calibrado contra el requisito de calidad del proyecto: ninguna
acción del usuario debe superar los 2 segundos. Medido en producción, cada
operación Argon2 costaba ~1,3 s sobre la CPU compartida de la instancia, lo
que dejaba el inicio de sesión en 1,8 s —y en 3,6 s cuando el correo no
existe, porque ese camino verifica además contra un hash señuelo.

El perfil actual —m=32 MiB, t=2, p=1— reduce el trabajo a un tercio y deja el
login holgadamente bajo el límite. Sigue por encima del mínimo que recomienda
OWASP para Argon2id (19 MiB, 2 iteraciones, paralelismo 1), así que la rebaja
es un ajuste al hardware disponible, no una renuncia al estándar. El
paralelismo baja a 1 porque en una CPU compartida los hilos adicionales
compiten entre sí sin aportar velocidad.

Los hashes ya almacenados llevan sus parámetros embebidos, de modo que siguen
verificándose sin problema; Django los recodifica con el perfil nuevo la
próxima vez que cada usuario inicia sesión.
"""
from django.contrib.auth.hashers import Argon2PasswordHasher


class HabitBuilderArgon2Hasher(Argon2PasswordHasher):
    memory_cost = 32 * 1024  # KiB
    time_cost = 2
    parallelism = 1
