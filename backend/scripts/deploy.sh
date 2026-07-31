#!/usr/bin/env bash
# Despliega el backend Django a Cloud Run usando secretos de .env.deploy
# (gitignored, nunca commiteado). Espejo de scripts/deploy.sh del backend Go.
#
# .env.deploy debe definir:
#   DATABASE_URL        postgres://...@ep-xxx.neon.tech/habitbuilder (Neon)
#   DJANGO_SECRET_KEY   clave larga aleatoria
#   JWT_SIGNING_KEY     clave dedicada para JWT (≠ DJANGO_SECRET_KEY)
#   ALLOWED_HOSTS       host del servicio Cloud Run (o *)
#   REGION              p. ej. us-central1
#   SERVICE_NAME        p. ej. habitbuilder-django
set -euo pipefail

cd "$(dirname "$0")/.."

ENV_FILE=".env.deploy"
if [ ! -f "$ENV_FILE" ]; then
  echo "Falta $ENV_FILE — copia .env.example a $ENV_FILE y completa valores reales." >&2
  exit 1
fi

set -a
# shellcheck disable=SC1090
source "$ENV_FILE"
set +a

: "${DATABASE_URL:?DATABASE_URL no está definida en $ENV_FILE}"
: "${DJANGO_SECRET_KEY:?DJANGO_SECRET_KEY no está definida en $ENV_FILE}"
: "${JWT_SIGNING_KEY:?JWT_SIGNING_KEY no está definida en $ENV_FILE}"
: "${ALLOWED_HOSTS:?ALLOWED_HOSTS no está definida en $ENV_FILE}"
: "${REGION:?REGION no está definida en $ENV_FILE}"
: "${SERVICE_NAME:?SERVICE_NAME no está definida en $ENV_FILE}"

echo "Desplegando $SERVICE_NAME a Cloud Run ($REGION)..."

gcloud run deploy "$SERVICE_NAME" \
  --source . \
  --region "$REGION" \
  --allow-unauthenticated \
  --set-env-vars "DATABASE_URL=${DATABASE_URL},DJANGO_SECRET_KEY=${DJANGO_SECRET_KEY},JWT_SIGNING_KEY=${JWT_SIGNING_KEY},ALLOWED_HOSTS=${ALLOWED_HOSTS},DEBUG=False" \
  --quiet
