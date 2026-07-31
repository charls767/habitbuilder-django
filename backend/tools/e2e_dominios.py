"""Suite E2E extendida: cubre los dominios que no toca e2e_despliegue.py.

Valida contra un despliegue real los flujos de metas, recordatorios (rutas en
español y alias móviles), seguimiento con filtros, progreso y estadísticas,
comunidad completa y todo el árbol administrativo.

El bloque de administración necesita un usuario con rol admin. Se promueve
mediante conexión directa a la base de datos, indicada con --db:

    python tools/e2e_dominios.py https://mi-api.example --db "postgres://..."

Sin --db, el bloque administrativo se omite (el resto se ejecuta igual).
"""
import sys
import uuid
from datetime import date, timedelta

import requests

TIEMPO_ESPERA = 40


class Suite:
    def __init__(self, base):
        self.base = base.rstrip("/")
        self.filas = []
        self.fallos = 0
        self.token = None

    def pedir(self, ruta, *, metodo="GET", esperado=200, body=None, token=None,
              validar=None, etiqueta=None):
        headers = {}
        tok = token if token is not None else self.token
        if tok:
            headers["Authorization"] = f"Bearer {tok}"
        try:
            r = requests.request(metodo, self.base + ruta, json=body,
                                 headers=headers, timeout=TIEMPO_ESPERA)
        except requests.RequestException as exc:
            self._anotar(etiqueta or f"{metodo} {ruta}", 0, f"sin respuesta: {exc}", False)
            return None
        try:
            cuerpo = r.json() if r.content else None
        except ValueError:
            cuerpo = None
        estados = esperado if isinstance(esperado, (list, tuple)) else [esperado]
        ok = r.status_code in estados
        detalle = "" if ok else f"esperaba {estados}"
        if ok and validar:
            problema = validar(cuerpo)
            if problema:
                ok, detalle = False, problema
        self._anotar(etiqueta or f"{metodo} {ruta}", r.status_code, detalle, ok)
        return cuerpo

    def _anotar(self, nombre, estado, detalle, ok):
        self.filas.append((nombre, estado, detalle, ok))
        if not ok:
            self.fallos += 1

    def seccion(self, titulo):
        # Solo ASCII: la consola de Windows usa cp1252 y no admite box-drawing.
        self.filas.append((f"--- {titulo} ---", None, "", True))

    def imprimir(self):
        print("\n" + "=" * 76)
        print(f"SUITE POR DOMINIOS  ·  {self.base}")
        print("=" * 76)
        for nombre, estado, detalle, ok in self.filas:
            if estado is None:
                print(f"\n{nombre}")
                continue
            print(f"{'OK' if ok else 'FALLA':<7} {estado:<5} {nombre:<52} {detalle}")
        reales = [f for f in self.filas if f[1] is not None]
        print("-" * 76)
        print(f"{len(reales) - self.fallos}/{len(reales)} comprobaciones superadas")
        print("=" * 76)


def tiene(*claves):
    def _v(c):
        if not isinstance(c, dict):
            return "no es un objeto JSON"
        faltan = set(claves) - set(c)
        return f"faltan {sorted(faltan)}" if faltan else None
    return _v


def es_lista(minimo=0):
    def _v(c):
        if not isinstance(c, list):
            return "no es una lista"
        return None if len(c) >= minimo else f"esperaba >= {minimo} elementos"
    return _v


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        return 2
    base = sys.argv[1]
    db = None
    if "--db" in sys.argv:
        db = sys.argv[sys.argv.index("--db") + 1]

    s = Suite(base)
    sufijo = uuid.uuid4().hex[:8]
    email = f"dom-{sufijo}@habitbuilder.dev"
    clave = "Dominios-2026"
    ayer = (date.today() - timedelta(days=1)).isoformat()

    # ------------------------------------------------------------------
    s.seccion("IDENTIDAD")
    s.pedir("/v1/auth/register", metodo="POST", esperado=201,
            body={"nombre": "Dominios E2E", "email": email, "password": clave,
                  "terminosAceptados": True}, validar=tiene("usuario"))
    ses = s.pedir("/v1/auth/login", metodo="POST", esperado=200,
                  body={"email": email, "password": clave},
                  validar=tiene("token", "expiraEn"))
    if not isinstance(ses, dict):
        s.imprimir()
        return 1
    s.token = ses["token"]
    s.pedir("/v1/usuarios/me", metodo="PATCH", esperado=200,
            body={"zonaHoraria": "America/Bogota", "objetivoGeneral": "Completitud"},
            validar=lambda c: None if c["zonaHoraria"] == "America/Bogota" else "no aplico")
    s.pedir("/v1/usuarios/me", metodo="PATCH", esperado=400,
            body={"zonaHoraria": "Marte/Olympus"}, validar=tiene("mensaje", "errores"),
            etiqueta="PATCH /v1/usuarios/me (zona invalida)")

    # ------------------------------------------------------------------
    s.seccion("METAS")
    meta = s.pedir("/v1/metas", metodo="POST", esperado=201,
                   body={"descripcion": "Meta de completitud",
                         "fechaObjetivo": "2026-12-31"},
                   validar=tiene("id", "descripcion", "fechaObjetivo", "estado", "creadoEn"))
    mid = meta["id"] if isinstance(meta, dict) else None
    s.pedir("/v1/metas", validar=es_lista(1))
    if mid:
        s.pedir(f"/v1/metas/{mid}", validar=tiene("id", "estado"))
        s.pedir(f"/v1/metas/{mid}", metodo="PATCH", esperado=200,
                body={"descripcion": "Meta editada"},
                validar=lambda c: None if c["descripcion"] == "Meta editada" else "no aplico")
        s.pedir(f"/v1/metas/{mid}/estado", metodo="PATCH", esperado=200,
                body={"estado": "lograda"},
                validar=lambda c: None if c["estado"] == "lograda" else "estado incorrecto")
        s.pedir(f"/v1/metas/{mid}/estado", metodo="PATCH", esperado=400,
                body={"estado": "terminada"}, etiqueta="PATCH estado invalido -> 400")
    s.pedir(f"/v1/metas/{uuid.uuid4()}", esperado=404, etiqueta="GET meta inexistente -> 404")

    # ------------------------------------------------------------------
    s.seccion("HABITOS Y VINCULACION")
    hab = s.pedir("/v1/habitos", metodo="POST", esperado=201,
                  body={"nombre": "Habito dominios", "fechaInicio": "2026-07-01",
                        "frecuencia": {"tipo": "dias_especificos",
                                       "diasSemana": [1, 3, 5]},
                        "categoria": "salud"},
                  validar=lambda c: (None if c["frecuencia"]["diasSemana"] == [1, 3, 5]
                                     else "frecuencia mal serializada"))
    hid = hab["id"] if isinstance(hab, dict) else None
    if mid and hid:
        s.pedir(f"/v1/metas/{mid}/habitos", metodo="POST", esperado=200,
                body={"habitoIds": [hid]}, etiqueta="POST vincular habito a meta")
        s.pedir(f"/v1/habitos/{hid}",
                validar=lambda c: None if c["metaId"] == mid else "no quedo vinculado",
                etiqueta="GET habito (metaId asignado)")
        s.pedir(f"/v1/metas/{mid}/habitos/{hid}", metodo="DELETE", esperado=204,
                etiqueta="DELETE desvincular habito")
        s.pedir(f"/v1/metas/{mid}/habitos/{hid}", metodo="DELETE", esperado=404,
                etiqueta="DELETE desvincular repetido -> 404")

    # ------------------------------------------------------------------
    s.seccion("RECORDATORIOS")
    rid = None
    if hid:
        rec = s.pedir(f"/v1/habitos/{hid}/recordatorios", metodo="POST", esperado=201,
                      body={"mensaje": "  Recordatorio  ", "hora": "08:30",
                            "diasSemana": [5, 1, 3], "activo": True},
                      validar=lambda c: (None if c["diasSemana"] == [1, 3, 5]
                                         else "dias no normalizados"))
        rid = rec["id"] if isinstance(rec, dict) else None
        s.pedir(f"/v1/habitos/{hid}/recordatorios", validar=es_lista(1))
        s.pedir(f"/habits/{hid}/reminders", validar=es_lista(1),
                etiqueta="GET alias movil /habits/{id}/reminders")
        s.pedir(f"/v1/habitos/{hid}/recordatorios", metodo="POST", esperado=400,
                body={"mensaje": "x", "hora": "8:30", "diasSemana": [1], "activo": True},
                etiqueta="POST hora invalida -> 400")
        if rid:
            s.pedir(f"/reminders/{rid}", metodo="PATCH", esperado=200,
                    body={"mensaje": "Editado via alias", "hora": "21:15",
                          "diasSemana": [7], "activo": False},
                    etiqueta="PATCH alias movil /reminders/{id}")

    # ------------------------------------------------------------------
    s.seccion("SEGUIMIENTO, PROGRESO Y ESTADISTICAS")
    if hid:
        s.pedir(f"/v1/habitos/{hid}/registros", metodo="POST", esperado=201,
                body={"fechaLocal": ayer, "estado": "hecho", "nota": "  nota  "},
                validar=lambda c: None if c.get("nota") == "nota" else "nota sin recortar")
        s.pedir(f"/v1/habitos/{hid}/registros?desde={ayer}&hasta={ayer}",
                validar=es_lista(1), etiqueta="GET registros con rango de fechas")
        s.pedir(f"/v1/habitos/{hid}/registros?desde=ayer", esperado=400,
                etiqueta="GET rango invalido -> 400")
        s.pedir(f"/v1/habitos/{hid}/progreso?periodo=mes",
                validar=tiene("habitoId", "periodoDesde", "periodoHasta", "rachaActual",
                              "rachaMasLarga", "porcentaje", "estado"))
    s.pedir("/v1/progreso", validar=es_lista(1))
    s.pedir("/v1/estadisticas", validar=tiene("periodoDesde", "periodoHasta", "porcentaje",
                                              "mejorRacha", "masConsistentes",
                                              "masOmitidos", "estado"))
    s.pedir("/v1/estadisticas?periodo=anual", esperado=400,
            etiqueta="GET estadisticas periodo invalido -> 400")
    s.pedir(f"/v1/estadisticas?habitoId={uuid.uuid4()}", esperado=404,
            etiqueta="GET estadisticas habito ajeno -> 404")

    # ------------------------------------------------------------------
    s.seccion("COMUNIDAD")
    pub = s.pedir("/v1/comunidad/publicaciones", metodo="POST", esperado=201,
                  body={"contenido": "  Publicacion de completitud  "},
                  validar=tiene("id", "autorNombre", "contenido", "reacciones",
                                "comentarios", "reaccionada"))
    pid = pub["id"] if isinstance(pub, dict) else None
    s.pedir("/v1/comunidad/publicaciones?limit=5", validar=es_lista(1))
    s.pedir("/v1/comunidad/publicaciones?limit=0", esperado=400,
            etiqueta="GET feed limit invalido -> 400")
    s.pedir("/v1/comunidad/publicaciones", metodo="POST", esperado=400,
            body={"contenido": ""}, etiqueta="POST contenido vacio -> 400")
    if pid:
        com = s.pedir(f"/v1/comunidad/publicaciones/{pid}/comentarios", metodo="POST",
                      esperado=201, body={"contenido": "Comentario de prueba"},
                      validar=tiene("id", "publicacionId", "contenido", "creadoEn"))
        s.pedir(f"/v1/comunidad/publicaciones/{pid}/comentarios", validar=es_lista(1))
        s.pedir(f"/v1/comunidad/publicaciones/{pid}/reaccion", metodo="POST", esperado=204)
        s.pedir(f"/v1/comunidad/publicaciones/{pid}/reaccion", metodo="POST", esperado=204,
                etiqueta="POST reaccion repetida (idempotente) -> 204")
        s.pedir(f"/v1/comunidad/publicaciones/{pid}",
                validar=lambda c: (None if c["reacciones"] == 1 and c["reaccionada"]
                                   else f"contadores: {c['reacciones']}/{c['reaccionada']}"),
                etiqueta="GET publicacion (contadores)")
        s.pedir(f"/v1/comunidad/publicaciones/{pid}/reportes", metodo="POST", esperado=201,
                body={"motivo": "spam", "detalle": "prueba"},
                validar=tiene("id", "publicacionId", "motivo", "estado"))
        s.pedir(f"/v1/comunidad/publicaciones/{pid}/reportes", metodo="POST", esperado=409,
                body={"motivo": "acoso"}, etiqueta="POST reporte duplicado -> 409")
        if isinstance(com, dict):
            s.pedir(f"/v1/comunidad/comentarios/{com['id']}", metodo="DELETE", esperado=204)

    # ------------------------------------------------------------------
    s.seccion("INSPIRACION")
    s.pedir("/v1/inspiracion?limit=50", validar=es_lista(21),
            etiqueta="GET catalogo completo (21 del seed)")
    s.pedir("/v1/inspiracion?tipo=video&limit=5", validar=es_lista(1))
    s.pedir("/v1/inspiracion?limit=51", esperado=400,
            etiqueta="GET limite fuera de rango -> 400")

    # ------------------------------------------------------------------
    s.seccion("ADMINISTRACION")
    s.pedir("/v1/admin/usuarios", esperado=403, etiqueta="GET admin sin rol -> 403")
    sol = s.pedir("/v1/solicitudes-administrador", metodo="POST", esperado=201,
                  body={"motivo": "Solicitud de completitud"},
                  validar=tiene("id", "usuarioId", "motivo", "estado"))
    s.pedir("/v1/solicitudes-administrador", metodo="POST", esperado=409,
            body={"motivo": "otra"}, etiqueta="POST solicitud duplicada -> 409")
    s.pedir("/v1/solicitudes-administrador/me", validar=tiene("id", "estado"))

    if db:
        import psycopg
        with psycopg.connect(db, connect_timeout=30, autocommit=True) as con:
            con.execute("UPDATE usuarios SET rol='admin' WHERE email=%s", (email,))
        s.pedir("/v1/admin/usuarios", validar=es_lista(1),
                etiqueta="GET admin/usuarios (ya con rol admin)")
        s.pedir("/v1/admin/usuarios?rol=admin", validar=es_lista(1))
        s.pedir("/v1/admin/reportes/uso",
                validar=tiene("periodoDesde", "periodoHasta", "usuariosRegistrados",
                              "usuariosActivos", "habitosCreados", "registrosCreados",
                              "publicaciones"))
        s.pedir("/v1/admin/reportes/uso?desde=2026-12-31&hasta=2026-01-01", esperado=400,
                etiqueta="GET reporte rango invertido -> 400")
        # Filtrar por pendientes: el listado sin filtro devuelve tambien los ya
        # resueltos de ejecuciones anteriores, y resolver uno de esos daria 409.
        rep = s.pedir("/v1/admin/moderacion/reportes?estado=pendiente",
                      validar=es_lista(1))
        if isinstance(rep, list) and rep:
            s.pedir(f"/v1/admin/moderacion/reportes/{rep[0]['id']}", metodo="PATCH",
                    esperado=204, body={"resolucion": "ocultar", "razon": "prueba"},
                    etiqueta="PATCH resolver reporte (ocultar)")
            s.pedir(f"/v1/comunidad/publicaciones/{rep[0]['publicacionId']}", esperado=404,
                    etiqueta="GET publicacion oculta -> 404")
        cont = s.pedir("/v1/admin/inspiracion", metodo="POST", esperado=201,
                       body={"tipo": "articulo", "titulo": "Admin E2E",
                             "resumen": "Creado por la suite",
                             "url": "https://example.com/e2e", "autor": "Suite"},
                       validar=lambda c: None if c["publicado"] else "publicado deberia ser true")
        if isinstance(cont, dict):
            s.pedir(f"/v1/admin/inspiracion/{cont['id']}", metodo="PATCH", esperado=200,
                    body={"publicado": False},
                    validar=lambda c: None if not c["publicado"] else "no aplico")
            s.pedir(f"/v1/admin/inspiracion/{cont['id']}", metodo="DELETE", esperado=204)
            s.pedir(f"/v1/admin/inspiracion/{cont['id']}", esperado=404,
                    etiqueta="GET contenido eliminado -> 404")
        if isinstance(sol, dict):
            s.pedir(f"/v1/admin/solicitudes-administrador/{sol['id']}", metodo="PATCH",
                    esperado=200, body={"decision": "aprobar", "razon": "completitud"},
                    validar=lambda c: None if c["estado"] == "aprobada" else "no aprobada")

    s.imprimir()
    return 1 if s.fallos else 0


if __name__ == "__main__":
    sys.exit(main())
