# syntax=docker/dockerfile:1
# Imagen de producción del backend Django (espejo operacional del Dockerfile
# Go: igual que aquel corre las migraciones al arrancar y escucha en $PORT,
# que Cloud Run inyecta; 8080 es solo el default local).

FROM python:3.12-slim AS runtime

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PORT=8080

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY manage.py conftest.py pyproject.toml ./
COPY config ./config
COPY apps ./apps
COPY docs ./docs

RUN useradd --create-home appuser
USER appuser

EXPOSE 8080

# Migraciones al boot (paridad con postgres.RunMigrations en el main de Go)
# y gunicorn con workers/threads ajustados al tier pequeño de Cloud Run.
CMD ["sh", "-c", "python manage.py migrate --noinput && exec gunicorn config.wsgi:application --bind 0.0.0.0:${PORT} --workers ${GUNICORN_WORKERS:-2} --threads ${GUNICORN_THREADS:-4} --timeout 60 --access-logfile - --error-logfile -"]
