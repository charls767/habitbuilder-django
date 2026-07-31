"""Suite de pruebas de integración end-to-end contra un despliegue público.

Consume la API por HTTP como lo haría el cliente Flutter y valida el
cumplimiento estricto de docs/openapi.yaml: códigos de estado, forma exacta
de los payloads y semántica de los errores.

Uso:
    python tools/e2e_despliegue.py https://caacevedo767.pythonanywhere.com
    python tools/e2e_despliegue.py http://localhost:8000

Devuelve 0 si todas las comprobaciones pasan; 1 en caso contrario, e imprime
un reporte con la respuesta HTTP obtenida en cada paso.
"""
import json
import sys
import time
import uuid
from datetime import date, timedelta

import requests

TIEMPO_ESPERA = 30


class Reporte:
    def __init__(self, base: str):
        self.base = base.rstrip("/")
        self.filas: list[tuple[str, str, int, str, bool]] = []
        self.fallos = 0

    def comprobar(self, nombre, metodo, ruta, *, esperado, token=None, body=None,
                  validar=None):
        """Ejecuta una petición y verifica estado + forma del cuerpo."""
        headers = {"Authorization": f"Bearer {token}"} if token else {}
        url = self.base + ruta
        try:
            inicio = time.time()
            r = requests.request(
                metodo, url, json=body, headers=headers, timeout=TIEMPO_ESPERA
            )
            ms = int((time.time() - inicio) * 1000)
        except requests.RequestException as exc:
            self.filas.append((nombre, f"{metodo} {ruta}", 0, f"sin respuesta: {exc}", False))
            self.fallos += 1
            return None

        try:
            cuerpo = r.json() if r.content else None
        except ValueError:
            cuerpo = None

        estados = esperado if isinstance(esperado, (list, tuple)) else [esperado]
        ok = r.status_code in estados
        detalle = f"{ms}ms"
        if not ok:
            detalle = f"esperaba {estados}, recibio {r.status_code}"
        elif validar is not None:
            problema = validar(cuerpo)
            if problema:
                ok = False
                detalle = f"contrato: {problema}"

        self.filas.append((nombre, f"{metodo} {ruta}", r.status_code, detalle, ok))
        if not ok:
            self.fallos += 1
        return cuerpo

    def imprimir(self):
        print("\n" + "=" * 78)
        print(f"REPORTE E2E  ·  {self.base}")
        print("=" * 78)
        print(f"{'RESULTADO':<10} {'HTTP':<6} {'PETICION':<44} DETALLE")
        print("-" * 78)
        for nombre, peticion, estado, detalle, ok in self.filas:
            marca = "OK" if ok else "FALLA"
            print(f"{marca:<10} {estado:<6} {peticion:<44} {detalle}")
        print("-" * 78)
        total = len(self.filas)
        print(f"{total - self.fallos}/{total} comprobaciones superadas")
        if self.fallos:
            print(f"*** {self.fallos} FALLOS: el despliegue NO cumple el contrato ***")
        else:
            print("*** Despliegue operativo y conforme a openapi.yaml ***")
        print("=" * 78)


def claves(cuerpo, requeridas):
    """Verifica que el objeto tenga exactamente/al menos las claves del contrato."""
    if not isinstance(cuerpo, dict):
        return f"se esperaba un objeto JSON, llego {type(cuerpo).__name__}"
    faltan = requeridas - set(cuerpo)
    return f"faltan claves {sorted(faltan)}" if faltan else None


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        return 2
    rep = Reporte(sys.argv[1])
    sufijo = uuid.uuid4().hex[:10]
    email = f"e2e-{sufijo}@habitbuilder.dev"
    password = "E2E-Prueba-2026"

    # ---- 1. Salud del servicio -------------------------------------------
    rep.comprobar(
        "salud", "GET", "/health", esperado=200,
        validar=lambda c: claves(c, {"status", "database"})
        or (None if c.get("database") == "ok" else "la base de datos no responde"),
    )

    # ---- 2. Autenticación JWT --------------------------------------------
    rep.comprobar(
        "registro", "POST", "/v1/auth/register", esperado=201,
        body={"nombre": "Prueba E2E", "email": email, "password": password,
              "terminosAceptados": True},
        validar=lambda c: claves(c, {"usuario"})
        or claves(c["usuario"], {"id", "nombre", "email", "rol", "estado"})
        or ("password" in json.dumps(c) and "el payload filtra la contrasena" or None),
    )
    rep.comprobar(
        "registro duplicado -> 422", "POST", "/v1/auth/register", esperado=422,
        body={"nombre": "Prueba E2E", "email": email, "password": password,
              "terminosAceptados": True},
        validar=lambda c: claves(c, {"mensaje", "errores"}),
    )
    rep.comprobar(
        "credenciales invalidas -> 401", "POST", "/v1/auth/login", esperado=401,
        body={"email": email, "password": "clave-incorrecta"},
        validar=lambda c: claves(c, {"mensaje"}),
    )
    sesion = rep.comprobar(
        "login", "POST", "/v1/auth/login", esperado=200,
        body={"email": email, "password": password},
        validar=lambda c: claves(c, {"token", "expiraEn"}),
    )
    token = sesion.get("token") if isinstance(sesion, dict) else None
    if not token:
        rep.imprimir()
        return 1

    rep.comprobar(
        "sin token -> 401", "GET", "/v1/usuarios/me", esperado=401,
        validar=lambda c: claves(c, {"mensaje"}),
    )
    rep.comprobar(
        "perfil autenticado", "GET", "/v1/usuarios/me", esperado=200, token=token,
        validar=lambda c: claves(
            c, {"nombre", "email", "objetivoGeneral", "zonaHoraria",
                "accesibilidad", "notificaciones"}),
    )

    # ---- 3. Catálogo de inspiración --------------------------------------
    catalogo = rep.comprobar(
        "catalogo inspiracion", "GET", "/v1/inspiracion?limit=5", esperado=200,
        token=token,
        validar=lambda c: (
            "se esperaba una lista" if not isinstance(c, list)
            else (claves(c[0], {"id", "tipo", "titulo", "resumen", "url", "autor",
                                "destacado", "creadoEn", "actualizadoEn"}) if c
                  else "el catalogo esta vacio: faltan las migraciones de datos")
        ),
    )
    if isinstance(catalogo, list) and catalogo:
        rep.comprobar(
            "detalle inspiracion", "GET", f"/v1/inspiracion/{catalogo[0]['id']}",
            esperado=200, token=token,
            validar=lambda c: claves(c, {"id", "tipo", "titulo", "url"}),
        )
    rep.comprobar(
        "filtro tipo invalido -> 400", "GET", "/v1/inspiracion?tipo=podcast",
        esperado=400, token=token, validar=lambda c: claves(c, {"mensaje", "codigo"}),
    )

    # ---- 4. Gestión de hábitos -------------------------------------------
    habito = rep.comprobar(
        "crear habito", "POST", "/v1/habitos", esperado=201, token=token,
        body={"nombre": "Habito E2E", "fechaInicio": "2026-07-01",
              "frecuencia": {"tipo": "diaria"}, "categoria": "prueba"},
        validar=lambda c: claves(
            c, {"id", "nombre", "descripcion", "fechaInicio", "frecuencia",
                "categoria", "metaId", "estado", "creadoEn"}),
    )
    hid = habito.get("id") if isinstance(habito, dict) else None
    rep.comprobar(
        "frecuencia invalida -> 400", "POST", "/v1/habitos", esperado=400, token=token,
        body={"nombre": "Malo", "fechaInicio": "2026-07-01",
              "frecuencia": {"tipo": "dias_especificos"}},
        validar=lambda c: claves(c, {"mensaje"}),
    )
    rep.comprobar(
        "listar habitos", "GET", "/v1/habitos", esperado=200, token=token,
        validar=lambda c: None if isinstance(c, list) and c else "se esperaba una lista no vacia",
    )
    if hid:
        rep.comprobar(
            "obtener habito", "GET", f"/v1/habitos/{hid}", esperado=200, token=token,
            validar=lambda c: claves(c, {"id", "nombre", "estado"}),
        )
        rep.comprobar(
            "editar habito", "PATCH", f"/v1/habitos/{hid}", esperado=200, token=token,
            body={"nombre": "Habito E2E editado"},
            validar=lambda c: (None if c.get("nombre") == "Habito E2E editado"
                               else "la edicion no se aplico"),
        )
        rep.comprobar(
            "pausar habito", "POST", f"/v1/habitos/{hid}/pausar", esperado=200,
            token=token, body={"inicio": "2026-07-10"},
            validar=lambda c: (None if c.get("estado") == "pausado"
                               else f"estado inesperado: {c.get('estado')}"),
        )
        rep.comprobar(
            "reanudar habito", "POST", f"/v1/habitos/{hid}/reanudar", esperado=200,
            token=token,
            validar=lambda c: (None if c.get("estado") == "activo"
                               else f"estado inesperado: {c.get('estado')}"),
        )
        rep.comprobar(
            "registrar cumplimiento", "POST", f"/v1/habitos/{hid}/registros",
            esperado=201, token=token,
            body={"fechaLocal": (date.today() - timedelta(days=1)).isoformat(),
                  "estado": "hecho"},
            validar=lambda c: claves(c, {"id", "habitoId", "fechaLocal", "estado"}),
        )
        rep.comprobar(
            "upsert mismo dia -> 200", "POST", f"/v1/habitos/{hid}/registros",
            esperado=200, token=token,
            body={"fechaLocal": (date.today() - timedelta(days=1)).isoformat(),
                  "estado": "parcial"},
        )
        rep.comprobar(
            "progreso del habito", "GET", f"/v1/habitos/{hid}/progreso", esperado=200,
            token=token,
            validar=lambda c: claves(
                c, {"habitoId", "periodoDesde", "periodoHasta", "rachaActual",
                    "rachaMasLarga", "porcentaje", "estado"}),
        )
        rep.comprobar(
            "eliminar habito", "DELETE", f"/v1/habitos/{hid}", esperado=200,
            token=token, validar=lambda c: claves(c, {"habito", "impacto"}),
        )
    rep.comprobar(
        "habito inexistente -> 404", "GET", f"/v1/habitos/{uuid.uuid4()}",
        esperado=404, token=token, validar=lambda c: claves(c, {"mensaje"}),
    )
    rep.comprobar(
        "ruta admin sin rol -> 403", "GET", "/v1/admin/usuarios", esperado=403,
        token=token, validar=lambda c: claves(c, {"mensaje", "codigo"}),
    )

    rep.imprimir()
    return 1 if rep.fallos else 0


if __name__ == "__main__":
    sys.exit(main())
