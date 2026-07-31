"""Modelos del dominio 'identidad'.

Espejo de las migraciones Go 0001 (usuarios), 0002+0004 (perfiles) y
0003 (password_reset_tokens). Mismos nombres de tabla/columna vía db_table
y db_column para poder apuntar a la misma BD de Neon.

Diferencias deliberadas con AbstractBaseUser:
  - `password` se almacena en la columna `password_hash` (nombre de Go).
  - `last_login` se elimina: la tabla usuarios de Go no tiene esa columna.
  - Sin PermissionsMixin: la autorización es por el campo `rol`
    (regular/admin), igual que RequireAdmin en Go.
"""
import uuid

from django.contrib.auth.base_user import AbstractBaseUser, BaseUserManager
from django.db import models
from django.db.models.functions import Lower
from django.utils import timezone


class UsuarioManager(BaseUserManager):
    use_in_migrations = True

    def create_user(self, email: str, password: str | None = None, **extra):
        if not email:
            raise ValueError("El email es obligatorio")
        extra.setdefault("consentimiento_aceptado_en", timezone.now())
        extra.setdefault("consentimiento_version", "1.0")
        user = self.model(email=self.normalize_email(email), **extra)
        user.set_password(password)
        user.save(using=self._db)
        return user

    def create_superuser(self, email: str, password: str, **extra):
        extra.setdefault("rol", Usuario.Rol.ADMIN)
        return self.create_user(email, password, **extra)


class Usuario(AbstractBaseUser):
    """Tabla `usuarios` (migración 0001). Roles y estados confirmados en
    internal/identidad/domain/usuario.go."""

    class Rol(models.TextChoices):
        REGULAR = "regular"
        ADMIN = "admin"

    class Estado(models.TextChoices):
        ACTIVO = "activo"
        SUSPENDIDO = "suspendido"

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    nombre = models.TextField()
    email = models.EmailField()
    password = models.TextField(db_column="password_hash")
    rol = models.TextField(choices=Rol.choices, default=Rol.REGULAR)
    estado = models.TextField(choices=Estado.choices, default=Estado.ACTIVO)
    consentimiento_aceptado_en = models.DateTimeField()
    consentimiento_version = models.TextField()
    creado_en = models.DateTimeField(auto_now_add=True)

    last_login = None  # la tabla de Go no tiene esta columna

    objects = UsuarioManager()

    USERNAME_FIELD = "email"
    REQUIRED_FIELDS = ["nombre"]

    class Meta:
        db_table = "usuarios"
        constraints = [
            # CREATE UNIQUE INDEX usuarios_email_unique ON usuarios (lower(email))
            models.UniqueConstraint(Lower("email"), name="usuarios_email_unique"),
        ]

    @property
    def is_active(self) -> bool:  # requerido por simplejwt
        return self.estado == self.Estado.ACTIVO

    @property
    def es_admin(self) -> bool:
        return self.rol == self.Rol.ADMIN

    def check_password(self, raw_password: str) -> bool:
        """Puente para hashes heredados del backend Go.

        Go guarda el PHC crudo ($argon2id$v=19$m=...,t=...,p=...$salt$hash);
        Django guarda exactamente lo mismo con el prefijo "argon2$". Si el
        hash almacenado es formato Go, se verifica anteponiendo el prefijo
        (argon2-cffi lee los parámetros embebidos) y, si es correcto, se
        re-hashea al formato Django — migración transparente en el primer
        login tras el cambio de backend.
        """
        if self.password.startswith("$argon2id$"):
            from django.contrib.auth.hashers import get_hasher

            hasher = get_hasher("argon2")
            if hasher.verify(raw_password, "argon2" + self.password):
                self.set_password(raw_password)
                self.save(update_fields=["password"])
                return True
            return False
        return super().check_password(raw_password)


class Perfil(models.Model):
    """Tabla `perfiles` (migraciones 0002 y 0004)."""

    class TamanoTexto(models.TextChoices):
        NORMAL = "normal"
        GRANDE = "grande"
        EXTRA_GRANDE = "extra_grande"

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    usuario = models.OneToOneField(
        Usuario, on_delete=models.PROTECT, db_column="usuario_id", related_name="perfil"
    )
    objetivo_general = models.TextField(null=True)
    zona_horaria = models.TextField(default="UTC")
    tts_habilitado = models.BooleanField(default=False)
    tamano_texto = models.TextField(choices=TamanoTexto.choices, default=TamanoTexto.NORMAL)
    contraste_alto = models.BooleanField(default=False)
    notif_habilitadas = models.BooleanField(default=True)
    resumen_progreso_habilitado = models.BooleanField(default=True)  # 0004
    creado_en = models.DateTimeField(auto_now_add=True)
    actualizado_en = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = "perfiles"
        constraints = [
            models.CheckConstraint(
                condition=models.Q(tamano_texto__in=["normal", "grande", "extra_grande"]),
                name="perfiles_tamano_texto_check",
            ),
        ]


class PasswordResetToken(models.Model):
    """Tabla `password_reset_tokens` (migración 0003)."""

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    usuario = models.ForeignKey(
        Usuario, on_delete=models.PROTECT, db_column="usuario_id", related_name="reset_tokens"
    )
    token_hash = models.TextField()
    expires_at = models.DateTimeField()
    used_at = models.DateTimeField(null=True)
    creado_en = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "password_reset_tokens"
        constraints = [
            # "Un usuario tiene a lo sumo UN token de reset sin usar"
            # (borde de concurrencia AUTH-07, resuelto en la capa de BD).
            models.UniqueConstraint(
                fields=["usuario"],
                condition=models.Q(used_at__isnull=True),
                name="one_active_reset_token_per_user",
            ),
        ]
