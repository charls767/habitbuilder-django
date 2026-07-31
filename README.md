# HabitBuilder

Aplicación de seguimiento de hábitos: permite crear hábitos y metas, registrar el
cumplimiento diario, configurar recordatorios, consultar progreso y estadísticas, y
participar en una comunidad con contenido de inspiración y funciones administrativas.

Este repositorio reúne las dos mitades de la aplicación:

| Carpeta | Qué es | Tecnología |
|---|---|---|
| [`backend/`](backend/) | API REST | Python 3.12, Django 5.2, DRF, PostgreSQL |
| [`mobile/`](mobile/) | Cliente móvil | Flutter 3.44, Dart 3.12, Riverpod, go_router, Dio |

Ambas partes se comunican mediante el contrato **OpenAPI** que vive en
[`backend/docs/openapi.yaml`](backend/docs/openapi.yaml). Ese contrato es la fuente de
verdad: define cada endpoint, payload y código de estado, y ninguna de las dos partes
lo cambia por su cuenta.

## Contexto: la migración del backend

El backend se implementó originalmente en **Go 1.25** (repositorio
`habitbuilder-backend` en Bitbucket) y fue migrado a **Django + DRF** manteniendo
paridad byte a byte con el contrato, de modo que el cliente Flutter no necesitó ningún
cambio. La equivalencia se verificó ejecutando ambos backends en paralelo contra bases
de datos gemelas y comparando sus respuestas ante la misma secuencia de peticiones:
**110 de 110 pasos idénticos**. El detalle está en el
[README del backend](backend/README.md) y el arnés de comparación en
[`backend/tools/parity.py`](backend/tools/parity.py).

## Levantar la aplicación completa

### 1. Backend

Necesitas PostgreSQL. La forma más rápida es con Docker:

```bash
docker run -d --name habitbuilder-pg -e POSTGRES_PASSWORD=hb -e POSTGRES_USER=hb -e POSTGRES_DB=habitbuilder -p 5432:5432 postgres:16
```

Luego, desde `backend/`, prepara el entorno y arranca el servidor:

```bash
python -m venv .venv && .venv/Scripts/activate && pip install -r requirements.txt
```

```bash
cp .env.example .env
```

Edita `.env` con tus credenciales (para el PostgreSQL de arriba:
`DATABASE_URL=postgres://hb:hb@localhost:5432/habitbuilder` y `DB_SSLMODE=disable`), y
después:

```bash
python manage.py migrate && python manage.py runserver 0.0.0.0:8000
```

La API queda en `http://localhost:8000`; `GET /health` confirma que responde y que la
base de datos está accesible.

### 2. Cliente móvil

El cliente lee la URL del backend en tiempo de compilación mediante `API_BASE_URL`
(por defecto apunta a `http://localhost:4010`, el mock de Prism). Desde `mobile/`:

```bash
flutter pub get
```

Riverpod genera parte del código (`*.g.dart`), que no se versiona. Es obligatorio
generarlo antes de compilar o ejecutar pruebas, o fallarán con errores de símbolos no
definidos:

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

En un emulador de Android, `localhost` se refiere al propio emulador, así que el host
se alcanza por la dirección especial `10.0.2.2`:

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

Para que esa conexión funcione, el backend debe aceptar ese nombre de host: añade
`10.0.2.2` a `ALLOWED_HOSTS` en `backend/.env`. Si falta, Django responde `400 Bad
Request` (DisallowedHost) a todas las peticiones del emulador, sin mensaje JSON, lo
que despista bastante. El cliente también necesita permiso para hablar HTTP sin cifrar,
ya concedido solo en el perfil de depuración de Android.

En escritorio, web o iOS simulador, usa `localhost` directamente:

```bash
flutter run --dart-define=API_BASE_URL=http://localhost:8000
```

### Plataforma web

No existe un frontend web aparte: el mismo proyecto Flutter compila para navegador, así
que las 19 pantallas y toda la lógica son idénticas a las de móvil. Para ejecutarlo:

```bash
flutter run -d chrome --web-port=8080 --dart-define=API_BASE_URL=http://localhost:8000
```

Dos diferencias reales frente a móvil, ambas de plataforma y no de funcionalidad:

- **CORS es obligatorio.** El navegador aplica la política de origen cruzado, así que el
  backend debe declarar `CORS_ALLOWED_ORIGINS=http://localhost:8080` en `backend/.env`.
  Sin eso, Django responde sin la cabecera `Access-Control-Allow-Origin` y el navegador
  bloquea todas las peticiones (en móvil no ocurre: no hay origen que validar).
- **Sin notificaciones locales.** `flutter_local_notifications` no soporta web, y el
  código lo contempla: `reminder_scheduler_factory.dart` usa importación condicional y
  en navegador recurre a un planificador `noop`. Los recordatorios se crean, editan y
  consultan igual contra la API; lo único que no ocurre es la notificación del sistema.

El almacenamiento del token sí funciona: `flutter_secure_storage` tiene implementación
web oficial.

## Pruebas

El backend tiene 190 pruebas de contrato (228 casos con parametrización) que se ejecutan
contra un PostgreSQL real, con una puerta de cobertura del 80%. Desde `backend/`:

```bash
pytest
```

Desde `mobile/`, la suite del cliente:

```bash
flutter test
```

## Despliegue

El backend se empaqueta con un `Dockerfile` de producción (gunicorn, migraciones
automáticas al arrancar) que funciona en cualquier plataforma con soporte Docker.

### Render (recomendado para capa gratuita con Neon)

El repositorio incluye [`render.yaml`](render.yaml), así que basta con crear un
*Blueprint* apuntando a este repositorio: Render lee la configuración, construye la
imagen y genera por su cuenta `DJANGO_SECRET_KEY` y `JWT_SIGNING_KEY`. Solo hay que
pegar `DATABASE_URL` con la cadena de Neon (usa el endpoint *pooled*, que va mejor con
instancias que se apagan por inactividad).

No hace falta configurar el dominio a mano: Render inyecta `RENDER_EXTERNAL_HOSTNAME` y
`config/settings.py` lo añade a `ALLOWED_HOSTS` automáticamente.

Ten en cuenta que las instancias gratuitas se suspenden tras unos 15 minutos sin
tráfico, y la primera petición tras la suspensión tarda cerca de un minuto.

### Google Cloud Run

Arranques en frío más rápidos y una capa gratuita amplia, a cambio de requerir una
cuenta de Google Cloud con facturación activada. Con las credenciales en
`backend/.env.deploy`:

```bash
bash backend/scripts/deploy.sh
```

### PythonAnywhere

Requiere plan de pago: las cuentas gratuitas no admiten conexiones salientes a
PostgreSQL. Ver [la guía detallada](backend/docs/DESPLIEGUE-PYTHONANYWHERE.md).

### Validar cualquier despliegue

```bash
python backend/tools/e2e_despliegue.py https://TU-DOMINIO
```

## Créditos

Proyecto académico de calidad de software, desarrollado por Carlos Alberto Acevedo
Carmona y Omar Andrés Zambrano Arias. El historial de commits conserva la trazabilidad
con los tickets de Jira (`HBM-*` para el cliente móvil, `HBB-*` para el backend).
