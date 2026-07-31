# Despliegue en PythonAnywhere

Guía para publicar el backend Django en PythonAnywhere (ejemplo con el usuario
`caacevedo767`, servicio en `https://caacevedo767.pythonanywhere.com`).

## Requisito previo obligatorio: plan de pago

**Una cuenta gratuita no puede ejecutar este backend.** No es una limitación del
proyecto sino de la plataforma, y afecta por dos caminos independientes:

1. Las cuentas gratuitas solo permiten conexiones salientes HTTP/HTTPS hacia sitios
   de una lista blanca. PostgreSQL usa su propio protocolo sobre TCP, así que
   **no se puede conectar a Neon** (ni a ningún Postgres externo).
2. El PostgreSQL alojado por PythonAnywhere también es una función de pago.

Tampoco sirve migrar a MySQL (la base gratuita): el proyecto usa tipos propios de
PostgreSQL — `ArrayField` para `frecuencia_dias_semana` y `dias_semana`, claves
primarias compuestas e índices parciales — que MySQL no soporta.

Referencias oficiales:
[acceso externo](https://help.pythonanywhere.com/pages/AccessingPostgresFromOutsidePythonAnywhere/) ·
[Postgres en PythonAnywhere](https://help.pythonanywhere.com/pages/Postgres/) ·
[tipos de bases de datos](https://help.pythonanywhere.com/pages/KindsOfDatabases/)

## 1. Clonar el proyecto

En una consola Bash de PythonAnywhere:

```bash
git clone https://github.com/charls767/habitbuilder-django.git
```

## 2. Entorno virtual y dependencias

```bash
mkvirtualenv --python=/usr/bin/python3.12 habitbuilder && pip install -r ~/habitbuilder-django/backend/requirements.txt
```

Anota la ruta que imprime `which python` (algo como
`/home/caacevedo767/.virtualenvs/habitbuilder`): la necesitarás en la pestaña Web.

## 3. Variables de entorno

El proyecto lee su configuración de `backend/.env`. Créalo con tus credenciales
reales de Neon:

```bash
cat > ~/habitbuilder-django/backend/.env <<'EOF'
DJANGO_SECRET_KEY=<clave-larga-aleatoria>
JWT_SIGNING_KEY=<otra-clave-distinta>
DEBUG=False
ALLOWED_HOSTS=caacevedo767.pythonanywhere.com
DATABASE_URL=postgres://<usuario>:<password>@<host>.neon.tech/<base>
DB_SSLMODE=require
JWT_ACCESS_MINUTES=15
JWT_REFRESH_DAYS=7
CORS_ALLOWED_ORIGINS=https://caacevedo767.pythonanywhere.com
LOG_LEVEL=INFO
EOF
```

`ALLOWED_HOSTS` debe contener el dominio exacto: si falta, Django responde `400 Bad
Request` (DisallowedHost) a todas las peticiones, sin cuerpo JSON.

## 4. Migraciones

```bash
cd ~/habitbuilder-django/backend && python manage.py migrate
```

Esto crea las 16 tablas y carga el catálogo de inspiración (21 registros del seed).

## 5. Archivos estáticos: no aplica

**Este proyecto no tiene archivos estáticos y `collectstatic` no existe.** Es una API
JSON pura: `django.contrib.staticfiles` no está instalado, igual que no lo están el
admin ni las plantillas, porque no sirve ninguna página web. Ejecutar el comando
devuelve `Unknown command: 'collectstatic'`, lo cual es el comportamiento correcto.

En consecuencia, **no hay que configurar ningún mapeo de archivos estáticos** en la
pestaña Web. Si sigues un tutorial genérico de Django que lo pide, sáltate ese paso.

## 6. Configurar la aplicación web

En la pestaña **Web** del panel:

1. *Add a new web app* → **Manual configuration** → Python 3.12.
2. **Virtualenv**: la ruta del paso 2.
3. **Source code** y **Working directory**: `/home/caacevedo767/habitbuilder-django/backend`.
4. Edita el archivo WSGI (enlace *WSGI configuration file*) y reemplaza todo su
   contenido por lo siguiente:

```python
import os
import sys

ruta = "/home/caacevedo767/habitbuilder-django/backend"
if ruta not in sys.path:
    sys.path.insert(0, ruta)

os.environ["DJANGO_SETTINGS_MODULE"] = "config.settings"

from django.core.wsgi import get_wsgi_application  # noqa: E402

application = get_wsgi_application()
```

5. Pulsa **Reload**.

`config/settings.py` carga `backend/.env` automáticamente mediante django-environ, así
que no hace falta declarar variables en el panel.

## 7. Validar el despliegue

Desde tu máquina, ejecuta la suite de integración contra la URL pública:

```bash
python backend/tools/e2e_despliegue.py https://caacevedo767.pythonanywhere.com
```

Comprueba 23 casos sobre `/health`, autenticación JWT, catálogo de inspiración y
gestión completa de hábitos, validando códigos de estado y forma de los payloads
contra `docs/openapi.yaml`. Devuelve 0 solo si todo cumple el contrato.

## Alternativa sin plan de pago

Si no vas a contratar un plan, el proyecto ya incluye despliegue a **Google Cloud Run**
(`Dockerfile` + `scripts/deploy.sh`), que sí admite PostgreSQL externo en su capa
gratuita. La misma suite E2E sirve para validar ese despliegue apuntándola a su URL.
