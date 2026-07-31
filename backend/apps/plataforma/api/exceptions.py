"""Envelope de error del contrato HabitBuilder (paridad exacta con Go).

Formato CONFIRMADO leyendo docs/openapi.yaml (schema ErrorResponse) y los
structs Go en internal/*/infrastructure:

    {
        "mensaje": "texto legible",            # siempre presente
        "errores": {"campo": "detalle", ...},  # solo validación con detalle por campo
        "codigo": "invalid_request"            # solo algunos módulos (omitempty)
    }

Es un objeto PLANO (sin wrapper "error"). Campos ausentes se OMITEN, nunca
se envían como null — igual que `omitempty` en Go.

Semántica de códigos de estado observada en Go:
  - 401 middleware JWT: "falta el token de autenticación" (sin header) /
    "token inválido o expirado" (token malo).
  - Validación: identidad usa 422 con `errores` por campo (p. ej. registro);
    los demás módulos usan 400 (a menudo con codigo="invalid_request").
  - Los services eligen el status lanzando ContractError con el código que
    dicta openapi.yaml para su endpoint.
"""
from rest_framework import exceptions, status
from rest_framework.response import Response
from rest_framework.views import exception_handler as drf_exception_handler
from rest_framework_simplejwt.exceptions import InvalidToken

MENSAJE_FALTA_TOKEN = "falta el token de autenticación"  # noqa: S105 (mensaje, no secreto)
MENSAJE_TOKEN_INVALIDO = "token inválido o expirado"  # noqa: S105 (mensaje, no secreto)
MENSAJE_REQUIERE_ADMIN = "se requiere rol administrador"
MENSAJE_VALIDACION = "la solicitud contiene errores de validación"
MENSAJE_CUERPO_INVALIDO = "cuerpo de la solicitud inválido"


class ContractError(exceptions.APIException):
    """Excepción base que los services lanzan para responder según contrato.

    Ejemplos (espejo de los writeError del backend Go):
        raise ContractError("hábito no encontrado", status_code=404)
        raise ContractError(MENSAJE_VALIDACION, status_code=422,
                            errores={"email": "ya está registrado"})
        raise ContractError("el hábito no está activo para este recordatorio",
                            status_code=409, codigo="habit_inactive_for_reminder")
    """

    status_code = status.HTTP_400_BAD_REQUEST

    def __init__(
        self,
        mensaje: str,
        *,
        status_code: int | None = None,
        errores: dict[str, str] | None = None,
        codigo: str = "",
    ) -> None:
        super().__init__(detail=mensaje)
        if status_code is not None:
            self.status_code = status_code
        self.mensaje = mensaje
        self.errores = errores
        self.codigo = codigo


def _aplanar_errores(detail) -> dict[str, str]:
    """Convierte el detail de un ValidationError DRF (listas por campo) al
    mapa plano campo->mensaje del contrato (map[string]string en Go)."""
    if not isinstance(detail, dict):
        return {}
    planos: dict[str, str] = {}
    for campo, valor in detail.items():
        if isinstance(valor, (list, tuple)) and valor:
            planos[str(campo)] = str(valor[0])
        elif isinstance(valor, dict):
            anidados = _aplanar_errores(valor)
            if anidados:
                interno_campo, interno_msj = next(iter(anidados.items()))
                planos[f"{campo}.{interno_campo}"] = interno_msj
        else:
            planos[str(campo)] = str(valor)
    return planos


def contract_exception_handler(exc, context):
    response = drf_exception_handler(exc, context)
    if response is None:  # 500 no manejado: Django lo registra y responde
        return None

    if isinstance(exc, ContractError):
        body = {"mensaje": exc.mensaje}
        if exc.errores:
            body["errores"] = exc.errores
        if exc.codigo:
            body["codigo"] = exc.codigo
    elif isinstance(exc, exceptions.NotAuthenticated):
        body = {"mensaje": MENSAJE_FALTA_TOKEN}
    elif isinstance(exc, (exceptions.AuthenticationFailed, InvalidToken)):
        body = {"mensaje": MENSAJE_TOKEN_INVALIDO}
    elif isinstance(exc, exceptions.PermissionDenied):
        # RequireAdmin de Go: el único gate de permisos del sistema
        body = {"mensaje": MENSAJE_REQUIERE_ADMIN, "codigo": "forbidden"}
    elif isinstance(exc, exceptions.ValidationError):
        body = {"mensaje": MENSAJE_VALIDACION}
        errores = _aplanar_errores(exc.detail)
        if errores:
            body["errores"] = errores
    elif isinstance(exc, exceptions.ParseError):
        body = {"mensaje": MENSAJE_CUERPO_INVALIDO}
    else:
        body = {"mensaje": str(getattr(exc, "detail", exc))}

    return Response(body, status=response.status_code, headers=response.headers)
