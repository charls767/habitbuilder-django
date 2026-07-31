# HabitBuilder

Aplicación de seguimiento de hábitos. Permite crear hábitos y metas, registrar el
cumplimiento diario, configurar recordatorios, consultar progreso y estadísticas, y
participar en una comunidad con contenido de inspiración y funciones administrativas.

| Carpeta | Qué es | Tecnología |
|---|---|---|
| [`backend/`](backend/) | API REST | Python 3.12, Django 5.2, DRF, PostgreSQL |
| [`mobile/`](mobile/) | Cliente (móvil y web) | Flutter 3.44, Dart 3.12, Riverpod, go_router, Dio |

Ambas partes se comunican mediante el contrato **OpenAPI** que vive en
[`backend/docs/openapi.yaml`](backend/docs/openapi.yaml). Ese contrato es la fuente de
verdad: define cada endpoint, payload y código de estado, y ninguna de las dos partes lo
cambia por su cuenta.

## Funcionalidades

**Identidad.** Registro con aceptación de términos, inicio de sesión con JWT,
recuperación de contraseña por token de un solo uso y perfil editable con zona horaria
IANA y preferencias de accesibilidad.

**Hábitos.** Creación con tres tipos de frecuencia (diaria, días específicos, N veces
por periodo), edición, y ciclo de vida completo: pausar, reanudar, completar y eliminar.
El borrado es lógico —el hábito deja de listarse pero conserva su historial— y la
respuesta informa cuántos recordatorios y registros quedan afectados.

**Metas.** Creación con fecha objetivo, edición, cambio de estado (en progreso, lograda,
pausada, cancelada) y vinculación o desvinculación de hábitos. El estado lo decide el
usuario y nunca se deriva del estado de los hábitos asociados.

**Recordatorios.** Varios por hábito, con hora local, días de la semana y activación
individual. Un hábito pausado o completado no admite crear ni reactivar recordatorios,
aunque sí editarlos o desactivarlos. En móvil se programan notificaciones locales del
sistema.

**Seguimiento y progreso.** Registro diario del cumplimiento (hecho, parcial, omitido)
con nota opcional, idempotente por día para tolerar reintentos sin conexión. A partir de
ese historial se calculan rachas y porcentajes por periodo, y estadísticas agregadas con
los hábitos más constantes y más omitidos.

**Comunidad e inspiración.** Publicaciones con comentarios, reacciones y reportes, más
un catálogo de contenidos de inspiración (artículos, videos y audios).

**Administración.** Gestión de usuarios con cambio de rol y suspensión o reactivación,
reportes de uso agregados, moderación de la comunidad, CRUD del catálogo de inspiración
y un flujo de solicitud y aprobación de acceso administrativo. Toda acción administrativa
queda registrada en una bitácora de auditoría, y el sistema impide degradar o suspender
al último administrador activo.

## Arquitectura

El backend es un monolito modular: **una app de Django por contexto acotado**
(identidad, hábitos y metas, recordatorios, seguimiento, progreso, comunidad,
inspiración, administración y plataforma). Dentro de cada app la lógica de negocio vive
en `services.py`; las vistas DRF actúan solo como adaptadores HTTP, y los modelos se
mantienen delgados. No hay *fat models* ni *fat views*.

El cliente Flutter sigue una organización *feature-first* con capas de dominio, datos y
presentación. **El mismo código compila para Android, iOS, web y escritorio**: no existe
un frontend web aparte, así que las funcionalidades son idénticas en todas las
plataformas.

## Levantar el proyecto

### Backend

Necesitas PostgreSQL. La forma más rápida es con Docker:

```bash
docker run -d --name habitbuilder-pg -e POSTGRES_PASSWORD=hb -e POSTGRES_USER=hb -e POSTGRES_DB=habitbuilder -p 5432:5432 postgres:16
```

Desde `backend/`, prepara el entorno:

```bash
python -m venv .venv && .venv/Scripts/activate && pip install -r requirements.txt
```

```bash
cp .env.example .env
```

Edita `.env` con tus credenciales (para el PostgreSQL de arriba:
`DATABASE_URL=postgres://hb:hb@localhost:5432/habitbuilder` y `DB_SSLMODE=disable`), y
arranca:

```bash
python manage.py migrate && python manage.py runserver 0.0.0.0:8000
```

La API queda en `http://localhost:8000`. `GET /health` confirma que responde y que la
base de datos está accesible. No hay página de inicio ni panel de administración: es una
API JSON, así que la raíz `/` devuelve 404 y todo cuelga de `/v1/`.

### Cliente

El cliente lee la URL del backend en tiempo de compilación mediante `API_BASE_URL`. Desde
`mobile/`:

```bash
flutter pub get
```

Riverpod genera parte del código (`*.g.dart`), que no se versiona. Es obligatorio
generarlo antes de compilar o ejecutar pruebas, o fallarán con errores de símbolos no
definidos:

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

En un emulador de Android, `localhost` apunta al propio emulador, así que el equipo
anfitrión se alcanza por la dirección especial `10.0.2.2`:

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

Para que esa conexión funcione, añade `10.0.2.2` a `ALLOWED_HOSTS` en `backend/.env`. Si
falta, Django responde `400 Bad Request` (DisallowedHost) a todas las peticiones del
emulador, sin cuerpo JSON, lo que despista bastante.

En navegador:

```bash
flutter run -d chrome --web-port=8080 --dart-define=API_BASE_URL=http://localhost:8000
```

La web tiene dos particularidades de plataforma, no de funcionalidad. **CORS es
obligatorio**: el backend debe declarar `CORS_ALLOWED_ORIGINS=http://localhost:8080` o el
navegador bloqueará las respuestas. Y **no hay notificaciones locales**, porque
`flutter_local_notifications` no soporta web; el código lo contempla con importación
condicional y recurre a un planificador `noop`, de modo que los recordatorios se crean,
editan y consultan igual, pero sin aviso del sistema operativo.

## Pruebas

El backend tiene 190 pruebas de contrato (228 casos con parametrización) que se ejecutan
contra un PostgreSQL real, con una puerta de cobertura del 80%. Desde `backend/`:

```bash
pytest
```

La suite del cliente, desde `mobile/`:

```bash
flutter test
```

Además hay dos suites de integración que consumen un despliegue real por HTTP y validan
el cumplimiento del contrato. La primera cubre salud, autenticación, catálogo y hábitos;
la segunda recorre metas, recordatorios, seguimiento, estadísticas, comunidad y
administración:

```bash
python backend/tools/e2e_despliegue.py https://TU-DOMINIO
```

```bash
python backend/tools/e2e_dominios.py https://TU-DOMINIO
```

## Despliegue

El backend se empaqueta con un `Dockerfile` de producción (gunicorn, migraciones
automáticas al arrancar) que funciona en cualquier plataforma con soporte Docker.

### Render

El repositorio incluye [`render.yaml`](render.yaml), así que basta con crear un
*Blueprint* apuntando a este repositorio: Render lee la configuración, construye la
imagen y genera por su cuenta `DJANGO_SECRET_KEY` y `JWT_SIGNING_KEY`. Solo hay que pegar
`DATABASE_URL` con la cadena de PostgreSQL (con Neon, usa el endpoint *pooled*).

No hace falta configurar el dominio a mano: Render inyecta `RENDER_EXTERNAL_HOSTNAME` y
`config/settings.py` lo añade a `ALLOWED_HOSTS` automáticamente.

Ten en cuenta que las instancias gratuitas se suspenden tras unos 15 minutos sin tráfico,
y la primera petición tras la suspensión tarda cerca de un minuto.

### Cliente web

Se publica en GitHub Pages desde la rama `gh-pages`, compilado con la ruta base del
repositorio y apuntando a la API desplegada:

```bash
flutter build web --release --base-href "/habitbuilder-django/" --dart-define=API_BASE_URL=https://TU-API
```

Recuerda declarar el origen de la web en `CORS_ALLOWED_ORIGINS` del backend.

### Google Cloud Run

Arranques en frío más rápidos y una capa gratuita amplia, a cambio de requerir una cuenta
de Google Cloud con facturación activada. Con las credenciales en `backend/.env.deploy`:

```bash
bash backend/scripts/deploy.sh
```

### PythonAnywhere

Requiere plan de pago: las cuentas gratuitas no admiten conexiones salientes a
PostgreSQL. Ver [la guía detallada](backend/docs/DESPLIEGUE-PYTHONANYWHERE.md).

## Créditos

Proyecto académico de calidad de software, desarrollado por Carlos Alberto Acevedo
Carmona y Omar Andrés Zambrano Arias. El historial de commits conserva la trazabilidad
con los tickets de Jira (`HBM-*` para el cliente, `HBB-*` para el backend).
