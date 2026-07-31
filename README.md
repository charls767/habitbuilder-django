# HabitBuilder — Backend Django (migración desde Go 1.25)

Backend de HabitBuilder migrado de Go/chi a **Python 3.12+ / Django 5 / DRF**, manteniendo
paridad estricta con el contrato [docs/openapi.yaml](docs/openapi.yaml). El cliente Flutter
no debe notar el cambio de tecnología.

## 1. Estrategia de mapeo (hexagonal Go → Django)

| Concepto en Go (hexagonal) | Equivalente en Django | Ubicación |
|---|---|---|
| Contexto acotado (`internal/identidad`, `internal/comunidad`, …) | Django App | `apps/<dominio>/` |
| `domain/` (entidades, agregados, invariantes) | Modelos ORM **delgados** + reglas invariantes como métodos/validadores puros | `apps/<dominio>/models.py` |
| `application/` (casos de uso, comandos) | **Capa de servicios** — toda la lógica de negocio | `apps/<dominio>/services.py` |
| `application/` (queries, reportes de lectura) | Selectores de lectura (CQS ligero) | `apps/<dominio>/selectors.py` |
| `infrastructure/` — handlers HTTP de chi | Vistas DRF (`APIView`): solo validar, delegar, serializar | `apps/<dominio>/views.py` |
| `infrastructure/` — DTOs request/response | Serializers DRF (campos 1:1 con `openapi.yaml`) | `apps/<dominio>/serializers.py` |
| `infrastructure/` — repositorios pgx | Django ORM (los managers/querysets son el repositorio) | `models.py` / `selectors.py` |
| Router chi + middleware | `config/urls.py` (+ `urls.py` por app) y `MIDDLEWARE` | `config/` |
| `golang-migrate` (SQL versionado 0001–0017) | Migraciones nativas de Django | `apps/<dominio>/migrations/` |
| JWT propio + Argon2id | `djangorestframework-simplejwt` + `Argon2PasswordHasher` | `config/settings.py` |
| `platform` (transversal) | App `plataforma` (health, envelope de errores) — renombrada porque `platform` colisiona con la stdlib de Python | `apps/plataforma/` |
| Testcontainers | PostgreSQL de servicio en CI + `pytest-django` (BD de prueba real) | `bitbucket-pipelines.yml` |

Regla de oro: **ni fat models ni fat views**. Las vistas no contienen lógica de negocio;
los modelos no contienen orquestación. Todo caso de uso vive en `services.py` y se prueba
de forma aislada, igual que la capa `application` en Go.

## 2. Plan de fases

1. **Fase 0 — Inicialización** (esta carpeta): proyecto, 9 apps, settings por `.env`,
   JWT/Argon2id, manejador de errores del contrato, health check, pytest+ruff+CI. ✅
2. **Fase 1 — Contrato** ✅: `docs/openapi.yaml` congelado como fuente de verdad. Envelope
   de error **confirmado** contra el código Go (`internal/*/infrastructure`): objeto plano
   `{mensaje, errores?, codigo?}` con campos ausentes omitidos (paridad con `omitempty`).
   Implementado en `apps/plataforma/api/exceptions.py` (handler global + `ContractError`
   para los services) y fijado con pruebas de contrato en
   `apps/plataforma/tests/test_errores_contrato.py`. Mock de referencia:
   `npx @stoplight/prism-cli mock docs/openapi.yaml`.
3. **Fase 2 — Modelado ORM** ✅: las migraciones SQL 0001–0017 de
   `habitbuilder-backend/db/migration` están traducidas a modelos Django (16 tablas,
   mismos nombres de tabla/columna vía `db_table`/`db_column`). Incluye: PKs compuestas
   (`rachas_habito`, `reacciones_comunidad`, Django 5.2), índices parciales y funcional
   (`lower(email)`), CHECKs con `trim`/`length` (transforms en `apps/plataforma/db.py`)
   y el seed 0015 como data migration (`inspiracion/0002_seed_contenidos`). El seed 0016
   (promover emails a admin) no se replica: es dato de entorno, se hace con
   `createsuperuser`. Esquema validado aplicando `migrate` contra PostgreSQL 16 real
   (Docker) y comparando índices/constraints con `pg_indexes`/`pg_constraint`.
4. **Fase 3 — Identidad** ✅: los 6 endpoints (`/v1/auth/register|login|reset/request|
   reset/confirm|logout`, `/v1/usuarios/me` GET/PATCH) con paridad byte a byte: mensajes
   literales de Go, 422 con todos los campos a la vez (AUTH-02), guard de timing con hash
   dummy (AUTH-05), suspendido solo tras verificar credenciales (AUTH-06), reset silencioso
   y sha256-only (T-04), logout 204 sin revocación (según contrato) y
   `CHECK_USER_IS_ACTIVE=False` (el middleware Go no re-verifica estado por request).
   Hasher con parámetros de Go (t=3, m=64MiB, p=4) y puente para hashes heredados
   (PHC sin prefijo → verificar + re-hashear en el primer login), en
   `apps/identidad/hashers.py` y `Usuario.check_password`. 50 pruebas de contrato
   contra PostgreSQL real.
5. **Fase 4 — Hábitos/Metas, Recordatorios, Seguimiento, Progreso** ✅: CRUD y ciclo de
   vida de hábitos (transiciones exactas, soft-delete idempotente con impacto), metas y
   vinculación; recordatorios (rutas /v1 + alias móviles en inglés montados en la raíz,
   409 `habit_inactive_for_reminder`); registros con upsert idempotente 201/200 por clave
   natural y recálculo de racha no fatal; progreso/estadísticas con los algoritmos
   portados de `CalcularRacha`/`CalcularProgreso`/`GenerarInformeEstadisticas` (semanas
   ISO, pausas, clamp ≤100%, STATS-03 incluye hábitos eliminados; este módulo NO usa
   tildes en sus mensajes, igual que Go).
6. **Fase 5 — Comunidad** ✅: publicaciones (feed con moderación y soft-delete),
   comentarios, reacciones idempotentes (PK compuesta), reportes con 409
   `report_already_exists`; contadores por subconsultas correlacionadas como el SQL Go.
7. **Fase 6 — Inspiración pública** ✅: listado publicado (destacado DESC, recencia) con
   filtro tipo y paginación, y detalle; verificado contra el seed 0015 (21 filas).
8. **Fase 7 — Administración** ✅ (equivalente a HBB-54…62): permiso `EsAdministrador`
   (403 `forbidden`, espejo de RequireAdmin); gestión de usuarios con protección de
   último admin activo (409 `last_admin_protection`), prohibición de auto-cambio y
   auditoría en `auditoria_administrativa`; reporte de uso agregado (rango semiabierto,
   defaults now-30d); moderación (aprobar=descartar+visible, ocultar=resolver+oculto,
   con el 409 `report_already_exists` reutilizado de Go al re-resolver); inspiración
   administrable (CRUD, merge parcial en PATCH, default `publicado=true` al crear);
   y solicitudes de acceso (única pendiente por usuario → 409 `request_conflict`,
   aprobar promueve a admin + audita en la misma transacción).
8. **Fase 7 — Verificación de paridad** ✅: dual-run real con `tools/parity.py` — el
   binario Go (contenedor `golang:1.25`, BD gemela) y Django recibieron la MISMA
   secuencia de 112 peticiones cubriendo los 9 dominios; las respuestas (status +
   cuerpo JSON normalizado: UUIDs→marcadores, timestamps→`<ts>`, JWT→`<jwt>`) se
   compararon paso a paso. Resultado: **110/110 pasos comparados idénticos**.
   Hallazgos incorporados durante la verificación:
   - Los alias móviles en inglés (`/habits/*`, `/reminders/*`) están en
     `docs/openapi.yaml` (x-alias-of) pero el router de Go NUNCA los monta (404
     texto plano). Django los sirve (regla "contrato intocable"); son los 2 pasos
     excluidos de la comparación, como brecha documentada del backend Go.
   - Quirks de Go replicados a propósito: el 201 de crear comentario y de crear
     solicitud serializan el agregado en memoria (autorNombre=""; sin
     usuarioNombre/Email); en el feed la paginación no numérica y la fuera de rango
     responden mensajes distintos; y en /v1/admin/usuarios solo `rol` se valida
     contra el enum (estado inválido → 200 [], limit sin validar rango).
9. **Fase 8 — Despliegue** ✅ (empaquetado): `Dockerfile` de producción
   (python:3.12-slim, usuario no root, migraciones al boot como el main de Go, gunicorn
   escuchando en `$PORT` para Cloud Run) y `scripts/deploy.sh` espejo del de Go
   (`gcloud run deploy --source .` con secretos desde `.env.deploy`, gitignored).
   La imagen se validó corriendo en localhost (`SSL_REDIRECT=False` permite probarla
   por HTTP; en Cloud Run el redirect queda activo por defecto):

   ```
   docker build -t habitbuilder-django .
   docker run -p 8000:8080 -e DATABASE_URL=... -e DJANGO_SECRET_KEY=... \
     -e JWT_SIGNING_KEY=... -e DEBUG=False -e SSL_REDIRECT=False \
     -e ALLOWED_HOSTS=localhost habitbuilder-django
   ```

   El corte de tráfico y el rollback al binario Go quedan como decisión operativa
   (ambos servicios pueden convivir en Cloud Run bajo nombres distintos).

## 3. Desarrollo local

```bash
python -m venv .venv
.venv/Scripts/activate        # Windows
pip install -r requirements.txt
cp .env.example .env          # completar credenciales
python manage.py migrate
python manage.py runserver
```

Calidad:

```bash
ruff check .
pytest        # incluye puerta de cobertura >=80% (pyproject.toml)
```

## Reproducir la verificación de paridad (Go vs Django)

Requiere Docker. Levanta un PostgreSQL con dos BDs gemelas, el binario Go en un
contenedor `golang:1.25` y el servidor Django local; luego dispara la misma
secuencia (~112 peticiones) a ambos y compara respuestas normalizadas:

```bash
docker run -d --name hb-parity-pg -e POSTGRES_PASSWORD=hb -e POSTGRES_USER=hb -e POSTGRES_DB=hb_go -p 15433:5432 postgres:16
```

```bash
docker exec hb-parity-pg psql -U hb -d hb_go -c "CREATE DATABASE hb_dj OWNER hb;"
```

```bash
docker run -d --name hb-go -v "<ruta>/habitbuilder-backend:/app" -v hb-go-modcache:/go/pkg/mod -w /app -e DATABASE_URL="postgres://hb:hb@host.docker.internal:15433/hb_go?sslmode=disable" -e JWT_SECRET=paridad -e JWT_EXPIRATION_MINUTES=15 -p 18080:8080 golang:1.25 go run ./cmd/api
```

Con Django corriendo (`DATABASE_URL=postgres://hb:hb@localhost:15433/hb_dj DB_SSLMODE=disable python manage.py runserver 127.0.0.1:18001`):

```bash
python tools/parity.py http://127.0.0.1:18080 http://127.0.0.1:18001
```

Las corridas son destructivas: recrear ambas BDs (y reiniciar el contenedor Go,
que migra al arrancar) antes de repetir. Último resultado registrado:
**110/110 pasos comparados idénticos**; los 2 pasos de alias móviles se excluyen
por la brecha documentada del router Go.
