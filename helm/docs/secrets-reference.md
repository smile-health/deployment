# Secrets Reference — smile-health

All secrets live in the `smile-health` namespace. Each service mounts `common-secret`
plus its own service-specific secret via `envFrom.secretRef`.

---

## common-secret

Shared across all backend services.

| Key | Description |
|-----|-------------|
| `DB_HOST` | MySQL hostname — `mysql.smile-health.svc.cluster.local` |
| `DB_PORT` | MySQL port — `3306` |
| `DB_NAME` | Main database — `dev_smile_health` |
| `DB_USER` | MySQL user — `devel` |
| `DB_PASSWORD` | MySQL password |
| `DEV_DB_HOST` | Notification DB host (same as DB_HOST) |
| `DEV_DB_PORT` | Notification DB port — `3306` |
| `DEV_DB_DATABASE` | Notification DB name — `dev_smile_health_notification` |
| `DEV_DB_USERNAME` | Notification DB user — `devel` |
| `DEV_DB_PASSWORD` | Notification DB password |
| `DEV_DB_DIALECT` | `mysql` |
| `PROD_DB_*` | Same values as DEV_DB_* (notification uses both) |
| `REDIS_HOST` | `redis-master.smile-health.svc.cluster.local` |
| `REDIS_PORT` | `6379` |
| `REDIS_PASSWORD` | Redis password (empty if none) |
| `RABBITMQ_HOST` | `rabbitmq.smile-health.svc.cluster.local` |
| `RABBITMQ_PORT` | `5672` |
| `RABBITMQ_USERNAME` | RabbitMQ user — `devel` |
| `RABBITMQ_PASSWORD` | RabbitMQ password |
| `AMQP_SERVER` | Full AMQP URL — `amqp://devel:<pass>@rabbitmq.smile-health.svc.cluster.local:5672` |
| `APP_KEY` | JWT signing secret |
| `ENCRYPT_KEY` | Encryption key |
| `IV_KEY` | AES IV key |
| `SECRET` | General secret |
| `NODE_ENV` | `development` |
| `APP_URL` | `https://smile-health.badr.co.id` |
| `FRONTEND_URL` | `https://smile-health.badr.co.id` |
| `AUTH_URL` | `https://smile-health.badr.co.id/auth` |
| `CORE_API_URL` | `https://smile-health.badr.co.id/core` |
| `USER_SERVICE_SERVER_URL` | `https://smile-health.badr.co.id/core` |
| `LOKI_HOST` | Loki log aggregator URL |
| `LOKI_SEND` | `false` (disable if no Loki) |
| `OTLP_ENDPOINT` | OpenTelemetry collector endpoint |
| `SENTRY_DSN` | Sentry DSN (can be empty) |
| `MAIL_HOST` | SMTP host |
| `MAIL_PORT` | SMTP port |
| `MAIL_USERNAME` | SMTP user |
| `MAIL_PASSWORD` | SMTP password |
| `MAIL_FROM_ADDRESS` | From address |
| `TOLGEE_URL` | i18n service URL |
| `TOLGEE_API_KEY` | Tolgee API key |
| `TOLGEE_PROJECT_ID` | Tolgee project ID |
| `MINIO_ENDPOINT` | MinIO/S3 endpoint |
| `MINIO_PORT` | MinIO port |
| `MINIO_ACCESS_KEY` | MinIO access key |
| `MINIO_SECRET_KEY` | MinIO secret key |

---

## auth-secret

| Key | Description |
|-----|-------------|
| `PORT` | Service port — `3000` |
| `API_PREFIX` | Route prefix — `/auth` |
| `KEYCLOAK_SERVER_URL` | `https://keycloak.badr.co.id` |
| `KEYCLOAK_REALM` | `smile` |
| `KEYCLOAK_CLIENT_ID` | `smile` |
| `KEYCLOAK_CLIENT_SECRET` | Keycloak client secret (can be empty for public client) |
| `REALM_SYSUSER_NAME` | Keycloak system user for admin operations |
| `REALM_SYSUSER_PASS` | Keycloak system user password |
| `LOG_LEVEL` | `info` |
| `LOG_CALLER` | `false` |

---

## core-secret

| Key | Description |
|-----|-------------|
| `API_PREFIX` | `/core` |
| `APP_NAME` | `core-service` |
| `DB_NAME` | `dev_smile_health` (overrides common-secret for this service) |
| `DB_NAME_NOTIFICATION` | `dev_smile_health_notification` ⚠️ required — defaults to wrong DB if missing |
| `DATABASE_URL` | Full MySQL URL for Kysely migrations |
| `IMPORT_SHEET_USER` | Google Sheet import user |

---

## main-secret

| Key | Description |
|-----|-------------|
| `API_PREFIX` | `/main` (also handles `/account`) |
| `APP_NAME` | `main-service` |
| `DB_NAME` | `dev_smile_health` |
| `DATABASE_URL` | Full MySQL URL |
| `LIST_USE_CLICKHOUSE` | `false` |
| `IMPORT_SHEET_USER` | Google Sheet import user |

---

## warehouse-secret

| Key | Description |
|-----|-------------|
| `API_PREFIX` | `/warehouse-report` |
| `APP_NAME` | `warehouse-service` |
| `DB_NAME` | `dev_smile_health` |
| `CLICKHOUSE_DATABASE_URL` | ClickHouse URL (can be dummy if not used) |

---

## sync-secret

| Key | Description |
|-----|-------------|
| `APP_NAME` | `sync-service` |
| `DB_NAME` | `dev_smile_health_mapping` |
| `DATABASE_URL` | Full MySQL URL for mapping DB |
| `SYNC_SERVER_URL_IMMUNIZATION` | Upstream immunization system URL |
| `SYNC_SERVER_URL_LOGISTIC` | Upstream logistic system URL |

---

## notification-secret

| Key | Description |
|-----|-------------|
| `FCM_PROJECT_ID` | Firebase project ID |
| `GOOGLE_KEY` | Firebase service account JSON |
| `WHATSAPP_*` | WhatsApp gateway configuration |
| `SMS_*` | SMS gateway configuration |
| `AWS_ACCESS_KEY_ID` | AWS credentials (for SES/S3) |
| `AWS_SECRET_ACCESS_KEY` | AWS credentials |
| `COVID_API_*` | Legacy COVID reporting API |
| `ELASTIC_APM_DISABLE_SEND` | `true` |

---

## Creating secrets

Example for `common-secret`:

```bash
KUBECONFIG=~/.kube/config.badr-dev kubectl create secret generic common-secret \
  --namespace smile-health \
  --from-literal=DB_HOST=mysql.smile-health.svc.cluster.local \
  --from-literal=DB_PORT=3306 \
  --from-literal=DB_NAME=dev_smile_health \
  --from-literal=DB_USER=devel \
  --from-literal=DB_PASSWORD=<password> \
  --from-literal=RABBITMQ_HOST=rabbitmq.smile-health.svc.cluster.local \
  --from-literal=REDIS_HOST=redis-master.smile-health.svc.cluster.local \
  ...
```

Or apply a YAML file with base64-encoded values:

```bash
KUBECONFIG=~/.kube/config.badr-dev kubectl apply -f smile-health-secrets.yaml
```
