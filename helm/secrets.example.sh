#!/usr/bin/env bash
# smile-health secrets creation script
# Copy this file, fill in the values marked <CHANGE_ME>, and run it once
# against the smile-health namespace before deploying services.
#
# Usage: bash secrets.example.sh
#
# To update a single key in an existing secret:
#   kubectl patch secret -n smile-health <secret-name> --type='json' \
#     -p='[{"op":"add","path":"/data/<KEY>","value":"'$(echo -n "<value>" | base64)'"}]'

set -e

KUBECONFIG="${KUBECONFIG:-$HOME/.kube/config.badr-dev}"
NS="smile-health"
export KUBECONFIG

KC="kubectl --namespace $NS"

# ── Shared values (used in multiple secrets) ──────────────────────────────────
DB_HOST="mysql.smile-health.svc.cluster.local"
DB_PORT="3306"
DB_NAME="dev_smile_health"
DB_USER="devel"
DB_PASS="<CHANGE_ME>"                          # MySQL devel user password

REDIS_HOST="redis-master.smile-health.svc.cluster.local"
REDIS_PORT="6379"
REDIS_PASS=""                                  # leave empty if no Redis auth

RABBITMQ_HOST="rabbitmq.smile-health.svc.cluster.local"
RABBITMQ_PORT="5672"
RABBITMQ_USER="devel"
RABBITMQ_PASS="<CHANGE_ME>"                    # RabbitMQ password

APP_URL="https://smile-health.badr.co.id"

APP_KEY="<CHANGE_ME>"                          # JWT signing secret (random string)
ENCRYPT_KEY="<CHANGE_ME>"                      # Encryption key
IV_KEY="<CHANGE_ME>"                           # AES IV (16 bytes hex)
SECRET="<CHANGE_ME>"                           # General app secret

KEYCLOAK_URL="https://keycloak.badr.co.id"
KEYCLOAK_REALM="smile"
KEYCLOAK_CLIENT_ID="smile"
KEYCLOAK_CLIENT_SECRET=""                      # leave empty for public client
REALM_SYSUSER_NAME="<CHANGE_ME>"
REALM_SYSUSER_PASS="<CHANGE_ME>"

MINIO_ENDPOINT="<CHANGE_ME>"
MINIO_PORT="9000"
MINIO_ACCESS_KEY="<CHANGE_ME>"
MINIO_SECRET_KEY="<CHANGE_ME>"

TOLGEE_URL="<CHANGE_ME>"
TOLGEE_API_KEY="<CHANGE_ME>"
TOLGEE_PROJECT_ID="<CHANGE_ME>"

LOKI_HOST="<CHANGE_ME>"
OTLP_ENDPOINT="<CHANGE_ME>"
SENTRY_DSN=""

MAIL_HOST="<CHANGE_ME>"
MAIL_PORT="587"
MAIL_USERNAME="<CHANGE_ME>"
MAIL_PASSWORD="<CHANGE_ME>"
MAIL_FROM_ADDRESS="noreply@smile-health.badr.co.id"

# ── common-secret ─────────────────────────────────────────────────────────────
$KC create secret generic common-secret \
  --from-literal=DB_HOST="$DB_HOST" \
  --from-literal=DB_PORT="$DB_PORT" \
  --from-literal=DB_NAME="$DB_NAME" \
  --from-literal=DB_USER="$DB_USER" \
  --from-literal=DB_PASSWORD="$DB_PASS" \
  --from-literal=DEV_DB_HOST="$DB_HOST" \
  --from-literal=DEV_DB_PORT="$DB_PORT" \
  --from-literal=DEV_DB_DATABASE="dev_smile_health_notification" \
  --from-literal=DEV_DB_USERNAME="$DB_USER" \
  --from-literal=DEV_DB_PASSWORD="$DB_PASS" \
  --from-literal=DEV_DB_DIALECT="mysql" \
  --from-literal=PROD_DB_HOST="$DB_HOST" \
  --from-literal=PROD_DB_PORT="$DB_PORT" \
  --from-literal=PROD_DB_DATABASE="dev_smile_health_notification" \
  --from-literal=PROD_DB_USERNAME="$DB_USER" \
  --from-literal=PROD_DB_PASSWORD="$DB_PASS" \
  --from-literal=PROD_DB_DIALECT="mysql" \
  --from-literal=REDIS_HOST="$REDIS_HOST" \
  --from-literal=REDIS_PORT="$REDIS_PORT" \
  --from-literal=REDIS_PASSWORD="$REDIS_PASS" \
  --from-literal=RABBITMQ_HOST="$RABBITMQ_HOST" \
  --from-literal=RABBITMQ_PORT="$RABBITMQ_PORT" \
  --from-literal=RABBITMQ_USERNAME="$RABBITMQ_USER" \
  --from-literal=RABBITMQ_PASSWORD="$RABBITMQ_PASS" \
  --from-literal=AMQP_SERVER="amqp://${RABBITMQ_USER}:${RABBITMQ_PASS}@${RABBITMQ_HOST}:${RABBITMQ_PORT}" \
  --from-literal=APP_KEY="$APP_KEY" \
  --from-literal=ENCRYPT_KEY="$ENCRYPT_KEY" \
  --from-literal=IV_KEY="$IV_KEY" \
  --from-literal=SECRET="$SECRET" \
  --from-literal=NODE_ENV="development" \
  --from-literal=APP_URL="$APP_URL" \
  --from-literal=FRONTEND_URL="$APP_URL" \
  --from-literal=AUTH_URL="${APP_URL}/auth" \
  --from-literal=CORE_API_URL="${APP_URL}/core" \
  --from-literal=USER_SERVICE_SERVER_URL="${APP_URL}/core" \
  --from-literal=LOKI_HOST="$LOKI_HOST" \
  --from-literal=LOKI_SEND="false" \
  --from-literal=OTLP_ENDPOINT="$OTLP_ENDPOINT" \
  --from-literal=SENTRY_DSN="$SENTRY_DSN" \
  --from-literal=MAIL_HOST="$MAIL_HOST" \
  --from-literal=MAIL_PORT="$MAIL_PORT" \
  --from-literal=MAIL_USERNAME="$MAIL_USERNAME" \
  --from-literal=MAIL_PASSWORD="$MAIL_PASSWORD" \
  --from-literal=MAIL_FROM_ADDRESS="$MAIL_FROM_ADDRESS" \
  --from-literal=TOLGEE_URL="$TOLGEE_URL" \
  --from-literal=TOLGEE_API_KEY="$TOLGEE_API_KEY" \
  --from-literal=TOLGEE_PROJECT_ID="$TOLGEE_PROJECT_ID" \
  --from-literal=MINIO_ENDPOINT="$MINIO_ENDPOINT" \
  --from-literal=MINIO_PORT="$MINIO_PORT" \
  --from-literal=MINIO_ACCESS_KEY="$MINIO_ACCESS_KEY" \
  --from-literal=MINIO_SECRET_KEY="$MINIO_SECRET_KEY"
echo "✓ common-secret"

# ── auth-secret ───────────────────────────────────────────────────────────────
$KC create secret generic auth-secret \
  --from-literal=PORT="3000" \
  --from-literal=API_PREFIX="/auth" \
  --from-literal=KEYCLOAK_SERVER_URL="$KEYCLOAK_URL" \
  --from-literal=KEYCLOAK_REALM="$KEYCLOAK_REALM" \
  --from-literal=KEYCLOAK_CLIENT_ID="$KEYCLOAK_CLIENT_ID" \
  --from-literal=KEYCLOAK_CLIENT_SECRET="$KEYCLOAK_CLIENT_SECRET" \
  --from-literal=REALM_SYSUSER_NAME="$REALM_SYSUSER_NAME" \
  --from-literal=REALM_SYSUSER_PASS="$REALM_SYSUSER_PASS" \
  --from-literal=LOG_LEVEL="info" \
  --from-literal=LOG_CALLER="false"
echo "✓ auth-secret"

# ── core-secret ───────────────────────────────────────────────────────────────
$KC create secret generic core-secret \
  --from-literal=API_PREFIX="/core" \
  --from-literal=APP_NAME="core-service" \
  --from-literal=DB_NAME="$DB_NAME" \
  --from-literal=DB_NAME_NOTIFICATION="dev_smile_health_notification" \
  --from-literal=DATABASE_URL="mysql://${DB_USER}:${DB_PASS}@${DB_HOST}:${DB_PORT}/${DB_NAME}" \
  --from-literal=IMPORT_SHEET_USER="<CHANGE_ME>"
echo "✓ core-secret"

# ── main-secret ───────────────────────────────────────────────────────────────
$KC create secret generic main-secret \
  --from-literal=API_PREFIX="/main" \
  --from-literal=APP_NAME="main-service" \
  --from-literal=DB_NAME="$DB_NAME" \
  --from-literal=DATABASE_URL="mysql://${DB_USER}:${DB_PASS}@${DB_HOST}:${DB_PORT}/${DB_NAME}" \
  --from-literal=LIST_USE_CLICKHOUSE="false" \
  --from-literal=IMPORT_SHEET_USER="<CHANGE_ME>"
echo "✓ main-secret"

# ── warehouse-secret ──────────────────────────────────────────────────────────
$KC create secret generic warehouse-secret \
  --from-literal=API_PREFIX="/warehouse-report" \
  --from-literal=APP_NAME="warehouse-service" \
  --from-literal=DB_NAME="$DB_NAME" \
  --from-literal=CLICKHOUSE_DATABASE_URL="http://localhost:8123/default"
echo "✓ warehouse-secret"

# ── sync-secret ───────────────────────────────────────────────────────────────
SYNC_DB_NAME="dev_smile_health_mapping"
$KC create secret generic sync-secret \
  --from-literal=APP_NAME="sync-service" \
  --from-literal=DB_NAME="$SYNC_DB_NAME" \
  --from-literal=DATABASE_URL="mysql://${DB_USER}:${DB_PASS}@${DB_HOST}:${DB_PORT}/${SYNC_DB_NAME}" \
  --from-literal=SYNC_SERVER_URL_IMMUNIZATION="<CHANGE_ME>" \
  --from-literal=SYNC_SERVER_URL_LOGISTIC="<CHANGE_ME>"
echo "✓ sync-secret"

# ── notification-secret ───────────────────────────────────────────────────────
$KC create secret generic notification-secret \
  --from-literal=FCM_PROJECT_ID="<CHANGE_ME>" \
  --from-literal=GOOGLE_KEY="<CHANGE_ME>" \
  --from-literal=WHATSAPP_API_URL="<CHANGE_ME>" \
  --from-literal=WHATSAPP_API_KEY="<CHANGE_ME>" \
  --from-literal=SMS_API_URL="<CHANGE_ME>" \
  --from-literal=SMS_API_KEY="<CHANGE_ME>" \
  --from-literal=AWS_ACCESS_KEY_ID="<CHANGE_ME>" \
  --from-literal=AWS_SECRET_ACCESS_KEY="<CHANGE_ME>" \
  --from-literal=ELASTIC_APM_DISABLE_SEND="true"
echo "✓ notification-secret"

echo ""
echo "✓ All secrets created in namespace: $NS"
echo "  Deploy services next: ./smile-health-deploy.sh all"
