"""Verificación de paridad Go vs Django (Fase de paridad del plan).

Dispara la MISMA secuencia de peticiones a ambos backends (corriendo contra
bases de datos gemelas recién migradas) y compara código de estado y cuerpo
JSON normalizado:

  - los UUID se traducen a marcadores <u1>, <u2>... por orden de aparición
    (la secuencia es determinista, así que los mapas coinciden 1:1);
  - los timestamps ISO se reemplazan por <ts>; los JWT por <jwt>;
  - las fechas puras (YYYY-MM-DD) se conservan: ambos backends comparten
    reloj, y los cálculos de periodo deben coincidir literalmente.

Uso:
    python tools/parity.py http://127.0.0.1:18080 http://127.0.0.1:18001
"""
import json
import re
import sys
import uuid as uuid_lib
from datetime import date, timedelta

import requests

UUID_RE = re.compile(
    r"^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", re.I
)
TS_RE = re.compile(r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}")
JWT_RE = re.compile(r"^[\w-]+\.[\w-]+\.[\w-]+$")

HOY = date.today()
AYER = (HOY - timedelta(days=1)).isoformat()


class Normalizador:
    def __init__(self):
        self.uuids: dict[str, str] = {}

    def valor(self, v):
        if isinstance(v, str):
            if UUID_RE.match(v):
                if v not in self.uuids:
                    self.uuids[v] = f"<u{len(self.uuids) + 1}>"
                return self.uuids[v]
            if TS_RE.match(v):
                return "<ts>"
            if JWT_RE.match(v) and len(v) > 60:
                return "<jwt>"
        if isinstance(v, float):
            return round(v, 6)
        return v

    def normalizar(self, dato):
        if isinstance(dato, dict):
            return {k: self.normalizar(x) for k, x in sorted(dato.items())}
        if isinstance(dato, list):
            return [self.normalizar(x) for x in dato]
        return self.valor(dato)


class Backend:
    """Ejecuta la secuencia contra un backend y captura resultados."""

    def __init__(self, base: str):
        self.base = base
        self.norm = Normalizador()
        self.tokens: dict[str, str] = {}   # alias de usuario -> JWT
        self.ids: dict[str, str] = {}      # alias de recurso -> uuid real
        self.resultados: list[tuple[str, int, object]] = []

    def pedir(self, metodo, ruta, *, body=None, auth=None, guardar_id=None,
              guardar_token=None, nombre=None, excluir=False):
        """`excluir=True` marca pasos con divergencia CONOCIDA y documentada:
        los alias móviles en inglés están en docs/openapi.yaml (x-alias-of)
        pero el router de Go nunca los monta (404 texto plano). Django
        implementa el contrato; el paso se ejecuta pero no se compara."""
        headers = {}
        if auth:
            headers["Authorization"] = f"Bearer {self.tokens[auth]}"
        ruta_real = ruta.format(**self.ids)
        r = requests.request(
            metodo, self.base + ruta_real, json=body, headers=headers, timeout=30
        )
        try:
            cuerpo = r.json() if r.content else None
        except ValueError:
            cuerpo = f"<no-json:{r.content[:80]!r}>"
        if guardar_token and isinstance(cuerpo, dict):
            self.tokens[guardar_token] = cuerpo["token"]
        if guardar_id and isinstance(cuerpo, dict) and (cuerpo.get("id") or "usuario" in cuerpo):
            self.ids[guardar_id] = cuerpo.get("id") or cuerpo["usuario"]["id"]
        etiqueta = nombre or f"{metodo} {ruta}"
        # Un paso excluido no alimenta la tabla de traducción de UUIDs: en
        # el backend que no lo sirve no aparecen ids nuevos y los
        # marcadores <uN> quedarían desfasados para el resto de la corrida.
        cuerpo_norm = "<excluido>" if excluir else self.norm.normalizar(cuerpo)
        self.resultados.append((etiqueta, r.status_code, cuerpo_norm, excluir))

    def sql(self, comando):
        """Marcador para pasos fuera de banda (promociones por SQL)."""
        raise NotImplementedError


def ejecutar_secuencia(backend: Backend, promover_admin, suspender):
    b = backend
    reg = {"nombre": "Ana Paridad", "email": "ana@paridad.dev",
           "password": "S3gura-123", "terminosAceptados": True}

    # ---- identidad ----
    b.pedir("POST", "/v1/auth/register", body=reg, guardar_id="u1")
    b.pedir("POST", "/v1/auth/register", body=reg)                       # 422 dup
    b.pedir("POST", "/v1/auth/register", body={})                        # 422 todos
    b.pedir("POST", "/v1/auth/login",
            body={"email": "ana@paridad.dev", "password": "S3gura-123"},
            guardar_token="ana")
    b.pedir("POST", "/v1/auth/login",
            body={"email": "ana@paridad.dev", "password": "mala-clave"})  # 401
    b.pedir("POST", "/v1/auth/login",
            body={"email": "nadie@paridad.dev", "password": "S3gura-123"})  # 401
    b.pedir("POST", "/v1/auth/reset/request", body={"email": "ana@paridad.dev"})
    b.pedir("POST", "/v1/auth/reset/request", body={"email": "nadie@paridad.dev"})
    b.pedir("POST", "/v1/auth/reset/confirm",
            body={"token": "invalido", "nuevaPassword": "OtraClave-456"})  # 400
    b.pedir("GET", "/v1/usuarios/me", auth="ana")
    b.pedir("PATCH", "/v1/usuarios/me", auth="ana",
            body={"zonaHoraria": "America/Bogota", "objetivoGeneral": "Vivir mejor"})
    b.pedir("PATCH", "/v1/usuarios/me", auth="ana",
            body={"zonaHoraria": "Marte/Olympus"})                        # 400
    b.pedir("PATCH", "/v1/usuarios/me", auth="ana",
            body={"accesibilidad": {"ttsHabilitado": True, "tamanoTexto": "gigante",
                                    "contrasteAlto": False}})             # 400
    b.pedir("GET", "/v1/usuarios/me")                                     # 401
    b.pedir("POST", "/v1/auth/logout", auth="ana")                        # 204

    # ---- habitos ----
    b.pedir("POST", "/v1/habitos", auth="ana", guardar_id="h1",
            body={"nombre": "Leer", "fechaInicio": "2026-07-01",
                  "frecuencia": {"tipo": "diaria"}, "categoria": "  mente  "})
    b.pedir("POST", "/v1/habitos", auth="ana", guardar_id="h2",
            body={"nombre": "Gimnasio", "fechaInicio": "2026-07-01",
                  "frecuencia": {"tipo": "dias_especificos", "diasSemana": [1, 3, 5]}})
    b.pedir("POST", "/v1/habitos", auth="ana", guardar_id="h3",
            body={"nombre": "Meditar", "fechaInicio": "2026-07-01",
                  "frecuencia": {"tipo": "n_veces_por_periodo", "veces": 3,
                                 "periodo": "semana"}})
    b.pedir("POST", "/v1/habitos", auth="ana",
            body={"nombre": "Mal", "fechaInicio": "2026-07-01",
                  "frecuencia": {"tipo": "dias_especificos"}})             # 400
    b.pedir("POST", "/v1/habitos", auth="ana",
            body={"nombre": "Mal", "fechaInicio": "01/07/2026",
                  "frecuencia": {"tipo": "diaria"}})                       # 400 fecha
    b.pedir("GET", "/v1/habitos", auth="ana")
    b.pedir("GET", "/v1/habitos/{h1}", auth="ana")
    b.pedir("GET", "/v1/habitos/basura", auth="ana")                       # 404
    b.pedir("PATCH", "/v1/habitos/{h1}", auth="ana",
            body={"nombre": "Leer 30 min"})
    b.pedir("POST", "/v1/habitos/{h2}/pausar", auth="ana",
            body={"inicio": "2026-07-10"})
    b.pedir("POST", "/v1/habitos/{h2}/pausar", auth="ana",
            body={"inicio": "2026-07-11"})                                 # 400
    b.pedir("POST", "/v1/habitos/{h2}/reanudar", auth="ana")
    b.pedir("POST", "/v1/habitos/{h3}/completar", auth="ana")
    b.pedir("POST", "/v1/habitos/{h3}/completar", auth="ana")              # idempotente

    # ---- metas ----
    b.pedir("POST", "/v1/metas", auth="ana", guardar_id="m1",
            body={"descripcion": "Salud integral", "fechaObjetivo": "2026-12-31"})
    b.pedir("POST", "/v1/metas", auth="ana",
            body={"descripcion": "", "fechaObjetivo": "2026-12-31"})       # 400
    b.pedir("GET", "/v1/metas", auth="ana")
    b.pedir("PATCH", "/v1/metas/{m1}/estado", auth="ana", body={"estado": "lograda"})
    b.pedir("PATCH", "/v1/metas/{m1}/estado", auth="ana", body={"estado": "hecha"})  # 400
    b.pedir("POST", "/v1/metas/{m1}/habitos", auth="ana",
            body={"habitoIds": ["{h1}".format(**b.ids)]})
    b.pedir("GET", "/v1/habitos/{h1}", auth="ana")                          # con metaId
    b.pedir("DELETE", "/v1/metas/{m1}/habitos/{h1}", auth="ana")            # 204
    b.pedir("DELETE", "/v1/metas/{m1}/habitos/{h1}", auth="ana")            # 404

    # ---- recordatorios (es + alias en) ----
    b.pedir("POST", "/v1/habitos/{h1}/recordatorios", auth="ana", guardar_id="r1",
            body={"mensaje": "  A leer  ", "hora": "08:30",
                  "diasSemana": [5, 1, 3], "activo": True})
    b.pedir("POST", "/v1/habitos/{h1}/recordatorios", auth="ana",
            body={"mensaje": "x", "hora": "8:30", "diasSemana": [1], "activo": True})  # 400
    b.pedir("POST", "/v1/habitos/{h1}/recordatorios", auth="ana",
            body={"mensaje": "x", "hora": "08:30", "diasSemana": [1, 1],
                  "activo": True})                                          # 400
    b.pedir("GET", "/v1/habitos/{h1}/recordatorios", auth="ana")
    b.pedir("PATCH", "/v1/recordatorios/{r1}", auth="ana",
            body={"mensaje": "Editado", "hora": "21:00", "diasSemana": [7],
                  "activo": False})
    b.pedir("POST", "/v1/habitos/{h3}/recordatorios", auth="ana",
            body={"mensaje": "x", "hora": "08:30", "diasSemana": [1],
                  "activo": False})                                         # 409 completado
    b.pedir("DELETE", "/v1/recordatorios/{r1}", auth="ana")                 # 204
    b.pedir("DELETE", "/v1/recordatorios/{r1}", auth="ana")                 # 404
    # Alias móviles: en el contrato (x-alias-of) pero SIN montar en el
    # router Go → brecha documentada; solo se valida que Django los sirva.
    b.pedir("GET", "/habits/{h1}/reminders", auth="ana", excluir=True)
    b.pedir("POST", "/habits/{h1}/reminders", auth="ana", excluir=True,
            guardar_id="r2",
            body={"mensaje": "Via alias", "hora": "07:00", "diasSemana": [2],
                  "activo": True})

    # ---- seguimiento ----
    b.pedir("POST", "/v1/habitos/{h1}/registros", auth="ana", guardar_id="reg1",
            body={"fechaLocal": AYER, "estado": "hecho", "nota": "  bien  "})
    b.pedir("POST", "/v1/habitos/{h1}/registros", auth="ana",
            body={"fechaLocal": AYER, "estado": "parcial"})                 # 200 upsert
    b.pedir("POST", "/v1/habitos/{h1}/registros", auth="ana",
            body={"fechaLocal": HOY.isoformat(), "estado": "hecho"})
    b.pedir("POST", "/v1/habitos/{h1}/registros", auth="ana",
            body={"fechaLocal": (HOY + timedelta(days=3)).isoformat(),
                  "estado": "hecho"})                                       # 400 futura
    b.pedir("GET", "/v1/habitos/{h1}/registros", auth="ana")
    b.pedir("GET", f"/v1/habitos/{{h1}}/registros?desde={AYER}&hasta={AYER}",
            auth="ana")
    b.pedir("GET", "/v1/habitos/{h1}/registros?desde=ayer", auth="ana")     # 400

    # ---- progreso / estadisticas ----
    b.pedir("GET", "/v1/habitos/{h1}/progreso", auth="ana")
    b.pedir("GET", "/v1/habitos/{h1}/progreso?periodo=mes", auth="ana")
    b.pedir("GET", "/v1/habitos/{h1}/progreso?periodo=anual", auth="ana")   # 400
    b.pedir("GET", "/v1/progreso", auth="ana")
    b.pedir("GET", "/v1/estadisticas", auth="ana")
    b.pedir("GET", f"/v1/estadisticas?habitoId={uuid_lib.UUID(int=7)}",
            auth="ana")                                                     # 404

    # ---- comunidad ----
    reg2 = {"nombre": "Beto Paridad", "email": "beto@paridad.dev",
            "password": "S3gura-123", "terminosAceptados": True}
    b.pedir("POST", "/v1/auth/register", body=reg2, guardar_id="u2")
    b.pedir("POST", "/v1/auth/login",
            body={"email": "beto@paridad.dev", "password": "S3gura-123"},
            guardar_token="beto")
    b.pedir("POST", "/v1/comunidad/publicaciones", auth="ana", guardar_id="p1",
            body={"contenido": "  Hola comunidad  ", "habitoId": "{h1}".format(**b.ids)})
    b.pedir("POST", "/v1/comunidad/publicaciones", auth="ana",
            body={"contenido": ""})                                         # 400
    b.pedir("GET", "/v1/comunidad/publicaciones", auth="beto")
    b.pedir("GET", "/v1/comunidad/publicaciones?limit=0", auth="beto")      # 400
    b.pedir("PATCH", "/v1/comunidad/publicaciones/{p1}", auth="beto",
            body={"contenido": "hackeo"})                                   # 404 ajeno
    b.pedir("POST", "/v1/comunidad/publicaciones/{p1}/comentarios", auth="beto",
            guardar_id="c1", body={"contenido": "¡Bien ahí!"})
    b.pedir("GET", "/v1/comunidad/publicaciones/{p1}/comentarios", auth="ana")
    b.pedir("POST", "/v1/comunidad/publicaciones/{p1}/reaccion", auth="beto")  # 204
    b.pedir("POST", "/v1/comunidad/publicaciones/{p1}/reaccion", auth="beto")  # 204 idem
    b.pedir("GET", "/v1/comunidad/publicaciones/{p1}", auth="beto")
    b.pedir("POST", "/v1/comunidad/publicaciones/{p1}/reportes", auth="beto",
            guardar_id="rep1", body={"motivo": "spam", "detalle": "no me gusta"})
    b.pedir("POST", "/v1/comunidad/publicaciones/{p1}/reportes", auth="beto",
            body={"motivo": "acoso"})                                       # 409
    b.pedir("DELETE", "/v1/comunidad/comentarios/{c1}", auth="beto")        # 204

    # ---- inspiracion publica (seed identico) ----
    b.pedir("GET", "/v1/inspiracion?limit=5", auth="ana")
    b.pedir("GET", "/v1/inspiracion?tipo=video&limit=3", auth="ana")
    b.pedir("GET", "/v1/inspiracion?tipo=podcast", auth="ana")              # 400
    b.pedir("GET", "/v1/inspiracion/7f2d9c8e-3a14-4b7c-9d21-6f8e5a2c1b40", auth="ana")
    b.pedir("GET", f"/v1/inspiracion/{uuid_lib.UUID(int=9)}", auth="ana")   # 404

    # ---- administracion ----
    b.pedir("GET", "/v1/admin/usuarios", auth="ana")                        # 403
    promover_admin("ana@paridad.dev")
    b.pedir("POST", "/v1/auth/login",
            body={"email": "ana@paridad.dev", "password": "S3gura-123"},
            guardar_token="ana")  # re-login (rol se lee de BD por request)
    b.pedir("GET", "/v1/admin/usuarios", auth="ana")
    b.pedir("GET", "/v1/admin/usuarios?rol=admin", auth="ana")
    b.pedir("GET", "/v1/admin/usuarios?buscar=beto", auth="ana")
    b.pedir("GET", "/v1/admin/usuarios?estado=congelado", auth="ana")       # 400
    b.pedir("PATCH", "/v1/admin/usuarios/{u2}/estado", auth="ana",
            body={"estado": "suspendido", "razon": "prueba de paridad"})    # 204
    b.pedir("PATCH", "/v1/admin/usuarios/{u2}/estado", auth="ana",
            body={"estado": "activo", "razon": "restaurado"})               # 204
    b.pedir("PATCH", "/v1/admin/usuarios/{u1}/estado", auth="ana",
            body={"estado": "suspendido", "razon": "yo mismo"})             # 400 self
    b.pedir("PATCH", "/v1/admin/usuarios/{u2}/rol", auth="ana",
            body={"rol": "admin", "razon": "prueba"})                       # 204
    b.pedir("PATCH", "/v1/admin/usuarios/{u2}/rol", auth="ana",
            body={"rol": "regular", "razon": "revertido"})                  # 204
    b.pedir("PATCH", f"/v1/admin/usuarios/{uuid_lib.UUID(int=3)}/estado", auth="ana",
            body={"estado": "suspendido", "razon": "x"})                    # 404
    b.pedir("GET", "/v1/admin/reportes/uso?desde=2026-01-01&hasta=2026-12-31",
            auth="ana")
    b.pedir("GET", "/v1/admin/reportes/uso?desde=2026-12-31&hasta=2026-01-01",
            auth="ana")                                                     # 400

    # moderacion
    b.pedir("GET", "/v1/admin/moderacion/reportes", auth="ana")
    b.pedir("PATCH", "/v1/admin/moderacion/reportes/{rep1}", auth="ana",
            body={"resolucion": "ocultar", "razon": "confirmado"})          # 204
    b.pedir("GET", "/v1/comunidad/publicaciones/{p1}", auth="beto")         # 404 oculta
    b.pedir("PATCH", "/v1/admin/moderacion/reportes/{rep1}", auth="ana",
            body={"resolucion": "aprobar", "razon": "x"})                   # 409

    # inspiracion admin
    b.pedir("GET", "/v1/admin/inspiracion?limit=3", auth="ana")
    b.pedir("POST", "/v1/admin/inspiracion", auth="ana", guardar_id="i1",
            body={"tipo": "articulo", "titulo": "Paridad", "resumen": "Comparando",
                  "url": "https://example.com/paridad", "autor": "El Script"})
    b.pedir("PATCH", "/v1/admin/inspiracion/{i1}", auth="ana",
            body={"publicado": False})
    b.pedir("GET", "/v1/admin/inspiracion/{i1}", auth="ana")
    b.pedir("DELETE", "/v1/admin/inspiracion/{i1}", auth="ana")             # 204
    b.pedir("GET", "/v1/admin/inspiracion/{i1}", auth="ana")                # 404

    # solicitudes de acceso
    b.pedir("POST", "/v1/solicitudes-administrador", auth="beto", guardar_id="s1",
            body={"motivo": "  quiero ayudar  "})
    b.pedir("POST", "/v1/solicitudes-administrador", auth="beto",
            body={"motivo": "otra"})                                        # 409
    b.pedir("GET", "/v1/solicitudes-administrador/me", auth="beto")
    b.pedir("GET", "/v1/admin/solicitudes-administrador?estado=pendiente", auth="ana")
    b.pedir("PATCH", "/v1/admin/solicitudes-administrador/{s1}", auth="ana",
            body={"decision": "aprobar", "razon": "aprobada"})
    b.pedir("PATCH", "/v1/admin/solicitudes-administrador/{s1}", auth="ana",
            body={"decision": "rechazar", "razon": "x"})                    # 409
    b.pedir("GET", "/v1/admin/usuarios?rol=admin", auth="ana")              # beto ya admin


def main():
    base_go, base_dj = sys.argv[1], sys.argv[2]
    import subprocess

    def sql_en(db, comando):
        subprocess.run(
            ["docker", "exec", "hb-parity-pg", "psql", "-U", "hb", "-d", db,
             "-c", comando],
            check=True, capture_output=True,
        )

    resultados = {}
    for etiqueta, base, db in (("go", base_go, "hb_go"), ("django", base_dj, "hb_dj")):
        backend = Backend(base)
        ejecutar_secuencia(
            backend,
            promover_admin=lambda email, _db=db: sql_en(
                _db, f"UPDATE usuarios SET rol='admin' WHERE email='{email}'"
            ),
            suspender=lambda email, _db=db: sql_en(
                _db, f"UPDATE usuarios SET estado='suspendido' WHERE email='{email}'"
            ),
        )
        resultados[etiqueta] = backend.resultados

    pasos_go, pasos_dj = resultados["go"], resultados["django"]
    assert len(pasos_go) == len(pasos_dj)
    diferencias = 0
    excluidos = 0
    for (nombre, st_go, cuerpo_go, excluir), (_, st_dj, cuerpo_dj, _x) in zip(
        pasos_go, pasos_dj
    ):
        if excluir:
            excluidos += 1
            # el alias debe funcionar en Django aunque Go no lo sirva
            if st_dj >= 400:
                diferencias += 1
                print(f"\n=== ALIAS ROTO EN DJANGO: {nombre} → {st_dj} ===")
            continue
        if st_go != st_dj or cuerpo_go != cuerpo_dj:
            diferencias += 1
            print(f"\n=== DIFERENCIA: {nombre} ===")
            print(f"  go:     {st_go} {json.dumps(cuerpo_go, ensure_ascii=False)[:600]}")
            print(f"  django: {st_dj} {json.dumps(cuerpo_dj, ensure_ascii=False)[:600]}")
    total = len(pasos_go)
    comparados = total - excluidos
    print(f"\n{comparados - diferencias}/{comparados} pasos comparados idénticos; "
          f"{diferencias} diferencias; {excluidos} alias excluidos "
          f"(brecha documentada del router Go)")
    sys.exit(1 if diferencias else 0)


if __name__ == "__main__":
    main()
