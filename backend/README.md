# HabitBuilder — Backend

API REST de HabitBuilder: **Python 3.12, Django 5.2 y Django REST Framework**, sobre
PostgreSQL. Es una API JSON pura, sin plantillas, sin archivos estáticos y sin panel de
administración de Django; toda la interfaz vive en el cliente Flutter.

El contrato [`docs/openapi.yaml`](docs/openapi.yaml) es la fuente de verdad: define cada
endpoint, payload y código de estado. La API no se aparta de él.

## Arquitectura

Monolito modular con **una app de Django por contexto acotado**:

| App | Responsabilidad |
|---|---|
| `identidad` | Registro, sesión JWT, recuperación de contraseña, perfil |
| `habitosymetas` | Hábitos con su ciclo de vida y metas con vinculación |
| `recordatorios` | Recordatorios por hábito, con activación individual |
| `seguimiento` | Registro diario del cumplimiento |
| `progreso` | Rachas, porcentajes y estadísticas agregadas |
| `comunidad` | Publicaciones, comentarios, reacciones y reportes |
| `inspiracion` | Catálogo de contenidos, público y administrable |
| `administracion` | Usuarios, moderación, auditoría y solicitudes de acceso |
| `plataforma` | Salud del servicio y formato común de errores |

Dentro de cada app la responsabilidad se reparte así:

| Archivo | Contiene |
|---|---|
| `models.py` | Modelos ORM delgados: estructura e invariantes de datos |
| `services.py` | **Toda la lógica de negocio**: casos de uso y reglas |
| `selectors.py` | Consultas de lectura, separadas de los comandos |
| `serializers.py` | Serialización con los nombres exactos del contrato |
| `views.py` | Adaptadores HTTP: validan, delegan y responden |
| `urls.py` | Rutas del dominio, montadas bajo `/v1/` |

La regla es estricta: **ni *fat models* ni *fat views***. Una vista nunca contiene reglas
de negocio y un modelo nunca orquesta casos de uso.

## Decisiones de diseño

**Errores uniformes.** Un manejador global en `apps/plataforma/api/exceptions.py`
traduce toda excepción al envelope del contrato: un objeto plano
`{mensaje, errores?, codigo?}` donde los campos que no aplican se omiten en lugar de
viajar como `null`. Los servicios lanzan `ContractError` indicando estado, código y
detalle.

**Contraseñas con Argon2id** (`t=3`, `m=64 MiB`, `p=4`), perfil elegido para no exceder
la memoria de una instancia pequeña manteniendo un coste alto para un atacante.

**Sesión JWT sin estado**, con el identificador de usuario en el claim `sub`. El estado
de la cuenta no se re-verifica en cada petición: solo el inicio de sesión bloquea a un
usuario suspendido.

**Seguridad de la autenticación.** El inicio de sesión verifica siempre contra un hash
—uno ficticio si el correo no existe— para que el tiempo de respuesta no revele qué
cuentas están registradas. La recuperación de contraseña responde igual exista o no el
correo, y solo persiste el `sha256` del token.

**Modelo de usuario propio** (`identidad.Usuario`) con UUID como clave, correo único sin
distinguir mayúsculas y autorización por el campo `rol`.

**Protección del último administrador.** No se puede suspender ni degradar al único
administrador activo, y ningún administrador puede cambiar su propio rol o estado. Toda
acción administrativa deja rastro en `auditoria_administrativa`.

## Desarrollo local

```bash
python -m venv .venv && .venv/Scripts/activate && pip install -r requirements.txt
```

```bash
cp .env.example .env
```

Completa `.env` con tus credenciales y arranca:

```bash
python manage.py migrate && python manage.py runserver
```

## Calidad

```bash
ruff check .
```

```bash
pytest
```

La suite son 203 pruebas de contrato (241 casos con parametrización) que se ejecutan
contra un PostgreSQL real y verifican códigos de estado y payloads exactos, con una
puerta de cobertura del 80% configurada en `pyproject.toml`.

Para validar un despliegue ya publicado, dos suites de integración consumen la API por
HTTP como lo haría el cliente:

```bash
python tools/e2e_despliegue.py https://TU-DOMINIO
```

```bash
python tools/e2e_dominios.py https://TU-DOMINIO
```

Todo esto se ejecuta automáticamente en cada cambio mediante
[`.github/workflows/ci.yml`](../.github/workflows/ci.yml), que levanta un PostgreSQL de
servicio y aplica las mismas comprobaciones que en local.

## Despliegue

`Dockerfile` de producción con gunicorn, usuario sin privilegios y migraciones aplicadas
al arrancar. Escucha en `$PORT`, de modo que funciona directamente en Render, Cloud Run o
cualquier plataforma con soporte Docker. Las guías por plataforma están en el
[README del repositorio](../README.md) y en
[`docs/DESPLIEGUE-PYTHONANYWHERE.md`](docs/DESPLIEGUE-PYTHONANYWHERE.md).
