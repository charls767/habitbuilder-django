"""
Configuración Django de HabitBuilder (migración desde Go 1.25 / chi).

Principios:
  - Paridad estricta con docs/openapi.yaml (el cliente Flutter no debe notar el cambio).
  - Toda credencial/entorno viene de variables de entorno (.env), nunca del código.
  - Argon2id como hasher primario (paridad con el backend Go).
  - JWT stateless con djangorestframework-simplejwt (paridad con el JWT de Go).
"""
from datetime import timedelta
from pathlib import Path

import environ

BASE_DIR = Path(__file__).resolve().parent.parent

# ---------------------------------------------------------------------------
# Entorno (.env) — django-environ
# ---------------------------------------------------------------------------
env = environ.Env(
    DEBUG=(bool, False),
    ALLOWED_HOSTS=(list, []),
    CORS_ALLOWED_ORIGINS=(list, []),
    JWT_ACCESS_MINUTES=(int, 15),
    JWT_REFRESH_DAYS=(int, 7),
)
environ.Env.read_env(BASE_DIR / ".env")

SECRET_KEY = env("DJANGO_SECRET_KEY")
DEBUG = env("DEBUG")
ALLOWED_HOSTS = env("ALLOWED_HOSTS")

# Render asigna el dominio en tiempo de despliegue, así que no puede conocerse
# al configurar las variables: se añade solo si la plataforma lo inyecta.
_host_render = env("RENDER_EXTERNAL_HOSTNAME", default="")
if _host_render:
    ALLOWED_HOSTS = [*ALLOWED_HOSTS, _host_render]

# ---------------------------------------------------------------------------
# Aplicaciones — una app Django por contexto acotado del monolito Go
# ---------------------------------------------------------------------------
DJANGO_APPS = [
    "django.contrib.auth",
    "django.contrib.contenttypes",
    "django.contrib.postgres",  # ArrayField (frecuencia_dias_semana, dias_semana)
    # Sin admin/sessions/messages/staticfiles: es una API pura JSON.
]

THIRD_PARTY_APPS = [
    "rest_framework",
    "rest_framework_simplejwt.token_blacklist",  # soporta POST /v1/auth/logout
    "corsheaders",
    "drf_spectacular",  # exportar el esquema y compararlo contra docs/openapi.yaml
]

LOCAL_APPS = [
    "apps.plataforma",       # health, errores comunes, middleware transversal
    "apps.identidad",        # /v1/auth/*, /v1/usuarios/me
    "apps.habitosymetas",    # /v1/habitos*, /v1/metas*
    "apps.recordatorios",    # /v1/habitos/{id}/recordatorios, /v1/recordatorios/{id}
    "apps.seguimiento",      # /v1/habitos/{id}/registros
    "apps.progreso",         # /v1/progreso, /v1/estadisticas, /v1/habitos/{id}/progreso
    "apps.comunidad",        # /v1/comunidad/*
    "apps.inspiracion",      # /v1/inspiracion*
    "apps.administracion",   # /v1/admin/*, /v1/solicitudes-administrador*
]

INSTALLED_APPS = DJANGO_APPS + THIRD_PARTY_APPS + LOCAL_APPS

MIDDLEWARE = [
    "django.middleware.security.SecurityMiddleware",
    "corsheaders.middleware.CorsMiddleware",
    "django.middleware.common.CommonMiddleware",
]

ROOT_URLCONF = "config.urls"
WSGI_APPLICATION = "config.wsgi.application"
ASGI_APPLICATION = "config.asgi.application"

# API pura: sin templates de servidor.
TEMPLATES: list = []

# ---------------------------------------------------------------------------
# Base de datos — PostgreSQL (Neon). DATABASE_URL ej.:
#   postgres://user:pass@ep-xxx.neon.tech/habitbuilder?sslmode=require
# ---------------------------------------------------------------------------
DATABASES = {
    "default": {
        **env.db("DATABASE_URL"),
        "CONN_MAX_AGE": 60,          # pooling básico; Neon cierra conexiones ociosas
        "CONN_HEALTH_CHECKS": True,
        "OPTIONS": {"sslmode": env("DB_SSLMODE", default="require")},
    }
}
DEFAULT_AUTO_FIELD = "django.db.models.BigAutoField"

# ---------------------------------------------------------------------------
# Identidad — modelo de usuario propio (paridad con el agregado Usuario de Go)
# ---------------------------------------------------------------------------
AUTH_USER_MODEL = "identidad.Usuario"

# auth.E003 exige unique=True en USERNAME_FIELD, pero la unicidad del email
# la garantiza el índice funcional usuarios_email_unique sobre lower(email)
# (paridad con la migración Go 0001, y case-insensitive: más estricto que
# unique=True). Añadir unique=True crearía un segundo índice que Go no tiene.
SILENCED_SYSTEM_CHECKS = ["auth.E003"]

# Argon2id con los parámetros exactos del backend Go (t=3, m=64MiB, p=4).
# Los hashes heredados de Go (PHC sin prefijo "argon2$") se verifican y
# re-hashean en Usuario.check_password (apps/identidad/models.py).
PASSWORD_HASHERS = [
    "apps.identidad.hashers.HabitBuilderArgon2Hasher",
    "django.contrib.auth.hashers.Argon2PasswordHasher",
    "django.contrib.auth.hashers.PBKDF2PasswordHasher",
]

AUTH_PASSWORD_VALIDATORS = [
    {"NAME": "django.contrib.auth.password_validation.MinimumLengthValidator",
     "OPTIONS": {"min_length": 8}},
    {"NAME": "django.contrib.auth.password_validation.CommonPasswordValidator"},
    {"NAME": "django.contrib.auth.password_validation.NumericPasswordValidator"},
]

# ---------------------------------------------------------------------------
# DRF — respuestas y errores idénticos al contrato actual
# ---------------------------------------------------------------------------
REST_FRAMEWORK = {
    "DEFAULT_AUTHENTICATION_CLASSES": (
        "rest_framework_simplejwt.authentication.JWTAuthentication",
    ),
    "DEFAULT_PERMISSION_CLASSES": (
        "rest_framework.permissions.IsAuthenticated",
    ),
    "DEFAULT_RENDERER_CLASSES": (
        "rest_framework.renderers.JSONRenderer",  # solo JSON, como el backend Go
    ),
    "DEFAULT_PARSER_CLASSES": (
        "rest_framework.parsers.JSONParser",
    ),
    # Traduce excepciones al formato de error del openapi.yaml actual
    # (el backend Go define su propio envelope de error; se replica aquí).
    "EXCEPTION_HANDLER": "apps.plataforma.api.exceptions.contract_exception_handler",
    "DEFAULT_SCHEMA_CLASS": "drf_spectacular.openapi.AutoSchema",
    # La paginación del contrato se implementa por endpoint según openapi.yaml,
    # no con un default global que altere los payloads.
    "DEFAULT_PAGINATION_CLASS": None,
    "UNAUTHENTICATED_USER": None,
}

SPECTACULAR_SETTINGS = {
    "TITLE": "HabitBuilder API",
    "VERSION": "1.0.0",
    "SERVE_INCLUDE_SCHEMA": False,
}

# ---------------------------------------------------------------------------
# JWT — simplejwt (paridad con los tokens emitidos por Go)
# ---------------------------------------------------------------------------
SIMPLE_JWT = {
    "ACCESS_TOKEN_LIFETIME": timedelta(minutes=env("JWT_ACCESS_MINUTES")),
    "REFRESH_TOKEN_LIFETIME": timedelta(days=env("JWT_REFRESH_DAYS")),
    "ALGORITHM": "HS256",
    "SIGNING_KEY": env("JWT_SIGNING_KEY"),  # clave dedicada, distinta de SECRET_KEY
    "AUTH_HEADER_TYPES": ("Bearer",),
    "ROTATE_REFRESH_TOKENS": True,
    "BLACKLIST_AFTER_ROTATION": True,       # habilita logout real
    "USER_ID_FIELD": "id",
    "USER_ID_CLAIM": "sub",                 # claim 'sub' como en el JWT de Go
    # El middleware JWT de Go NO consulta el estado del usuario por request
    # (solo verifica firma y sub); un suspendido con token vigente puede leer
    # su perfil hasta que expire. Paridad exacta:
    "CHECK_USER_IS_ACTIVE": False,
}

# ---------------------------------------------------------------------------
# CORS / Seguridad
# ---------------------------------------------------------------------------
CORS_ALLOWED_ORIGINS = env("CORS_ALLOWED_ORIGINS")

SECURE_PROXY_SSL_HEADER = ("HTTP_X_FORWARDED_PROTO", "https")  # Cloud Run
if not DEBUG:
    # SSL_REDIRECT=False permite probar la imagen de producción por HTTP
    # en localhost; en Cloud Run se deja el default (True).
    SECURE_SSL_REDIRECT = env.bool("SSL_REDIRECT", default=True)
    SECURE_HSTS_SECONDS = 31536000
    SECURE_HSTS_INCLUDE_SUBDOMAINS = True
    SECURE_CONTENT_TYPE_NOSNIFF = True

# ---------------------------------------------------------------------------
# Internacionalización / logging
# ---------------------------------------------------------------------------
LANGUAGE_CODE = "es-co"
TIME_ZONE = "America/Bogota"
USE_TZ = True  # todo en UTC en BD; el contrato define los formatos de fecha

LOGGING = {
    "version": 1,
    "disable_existing_loggers": False,
    "formatters": {
        "json_like": {
            "format": '{"level":"%(levelname)s","logger":"%(name)s","msg":"%(message)s"}',
        },
    },
    "handlers": {
        "console": {"class": "logging.StreamHandler", "formatter": "json_like"},
    },
    "root": {"handlers": ["console"], "level": env("LOG_LEVEL", default="INFO")},
}
