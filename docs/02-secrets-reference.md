# Secrets Reference — smile-health

All secrets live in the `smile-health` namespace. Each backend service mounts `common-secret`
plus its own service-specific secret via `envFrom.secretRef` in the helm values.

The startup command writes all env vars to `.env` so dotenvx can load them:
```
printenv > .env && bun run src/server.ts
```

---

## common-secret

Shared across all backend services.

| Key | Value / Description |
|-----|---------------------|
| `DB_HOST` | `mysql.smile-health.svc.cluster.local` |
| `DB_PORT` | `3306` |
| `DB_NAME` | `dev_smile_health` |
| `DB_USER` | `devel` |
| `DB_PASSWORD` | MySQL password |
| `DEV_DB_HOST` | Same as DB_HOST (notification service) |
| `DEV_DB_PORT` | `3306` |
| `DEV_DB_DATABASE` | `dev_smile_health_notification` |
| `DEV_DB_USERNAME` | `devel` |
| `DEV_DB_PASSWORD` | MySQL password |
| `DEV_DB_DIALECT` | `mysql` |
| `PROD_DB_HOST` | Same as DEV_DB_HOST |
| `PROD_DB_PORT` | `3306` |
| `PROD_DB_DATABASE` | `dev_smile_health_notification` |
| `PROD_DB_USERNAME` | `devel` |
| `PROD_DB_PASSWORD` | MySQL password |
| `PROD_DB_DIALECT` | `mysql` |
| `REDIS_HOST` | `redis-master.smile-health.svc.cluster.local` |
| `REDIS_PORT` | `6379` |
| `REDIS_PASSWORD` | Redis password (empty if none) |
| `RABBITMQ_HOST` | `rabbitmq.smile-health.svc.cluster.local` |
| `RABBITMQ_PORT` | `5672` |
| `RABBITMQ_USERNAME` | `devel` |
| `RABBITMQ_PASSWORD` | RabbitMQ password |
| `AMQP_SERVER` | `amqp://devel:<pass>@rabbitmq.smile-health.svc.cluster.local:5672` |
| `APP_KEY` | JWT signing secret |
| `ENCRYPT_KEY` | Encryption key |
| `IV_KEY` | AES IV key |
| `SECRET` | General app secret |
| `NODE_ENV` | `development` |
| `APP_URL` | `https://smile-health.badr.co.id` |
| `FRONTEND_URL` | `https://smile-health.badr.co.id` |
| `AUTH_URL` | `https://smile-health.badr.co.id/auth` |
| `CORE_API_URL` | `https://smile-health.badr.co.id/core` |
| `USER_SERVICE_SERVER_URL` | `https://smile-health.badr.co.id/core` |
| `LOKI_HOST` | Loki log aggregator URL |
| `LOKI_SEND` | `false` |
| `OTLP_ENDPOINT` | OpenTelemetry collector endpoint |
| `SENTRY_DSN` | Sentry DSN (can be empty) |
| `MAIL_HOST` | SMTP host |
| `MAIL_PORT` | SMTP port |
| `MAIL_USERNAME` | SMTP username |
| `MAIL_PASSWORD` | SMTP password |
| `MAIL_FROM_ADDRESS` | From address for emails |
| `TOLGEE_URL` | i18n service URL |
| `TOLGEE_API_KEY` | Tolgee API key |
| `TOLGEE_PROJECT_ID` | Tolgee project ID |
| `MINIO_ENDPOINT` | MinIO/S3 endpoint |
| `MINIO_PORT` | MinIO port |
| `MINIO_ACCESS_KEY` | MinIO access key |
| `MINIO_SECRET_KEY` | MinIO secret key |

---

## auth-secret

| Key | Value / Description |
|-----|---------------------|
| `PORT` | `3000` |
| `API_PREFIX` | `/auth` |
| `KEYCLOAK_SERVER_URL` | `https://keycloak.badr.co.id` |
| `KEYCLOAK_REALM` | `smile` |
| `KEYCLOAK_CLIENT_ID` | `smile` |
| `KEYCLOAK_CLIENT_SECRET` | Keycloak client secret (empty for public client) |
| `REALM_SYSUSER_NAME` | Keycloak system user for admin operations |
| `REALM_SYSUSER_PASS` | Keycloak system user password |
| `LOG_LEVEL` | `info` |
| `LOG_CALLER` | `false` |

---

## core-secret

| Key | Value / Description |
|-----|---------------------|
| `API_PREFIX` | `/core` |
| `APP_NAME` | `core-service` |
| `DB_NAME` | `dev_smile_health` |
| `DB_NAME_NOTIFICATION` | `dev_smile_health_notification` ⚠️ **required** — if missing, defaults to wrong DB |
| `DATABASE_URL` | Full MySQL URL: `mysql://devel:<pass>@mysql.smile-health.svc.cluster.local:3306/dev_smile_health` |
| `IMPORT_SHEET_USER` | Google Sheet import user |

**Warning**: `DB_NAME_NOTIFICATION` must be explicitly set in `core-secret`. The code in
`apps/core/src/config/env.ts` defaults to `dev_smile_platform_notification` if this key is absent,
causing `Unknown database` errors on `/core/notifications/count`.

---

## main-secret

| Key | Value / Description |
|-----|---------------------|
| `API_PREFIX` | `/main` (also serves `/account`) |
| `APP_NAME` | `main-service` |
| `DB_NAME` | `dev_smile_health` |
| `DATABASE_URL` | Full MySQL URL |
| `LIST_USE_CLICKHOUSE` | `false` |
| `IMPORT_SHEET_USER` | Google Sheet import user |

---

## warehouse-secret

| Key | Value / Description |
|-----|---------------------|
| `API_PREFIX` | `/warehouse-report` |
| `APP_NAME` | `warehouse-service` |
| `DB_NAME` | `dev_smile_health` |
| `CLICKHOUSE_DATABASE_URL` | ClickHouse URL (dummy value if not used) |

---

## sync-secret

| Key | Value / Description |
|-----|---------------------|
| `APP_NAME` | `sync-service` |
| `DB_NAME` | `dev_smile_health_mapping` |
| `DATABASE_URL` | `mysql://devel:<pass>@mysql.smile-health.svc.cluster.local:3306/dev_smile_health_mapping` |
| `SYNC_SERVER_URL_IMMUNIZATION` | Upstream immunization system URL |
| `SYNC_SERVER_URL_LOGISTIC` | Upstream logistic system URL |

---

## notification-secret

| Key | Value / Description |
|-----|---------------------|
| `FCM_PROJECT_ID` | Firebase project ID |
| `GOOGLE_KEY` | Firebase service account JSON |
| `WHATSAPP_API_URL` | WhatsApp gateway URL |
| `WHATSAPP_API_KEY` | WhatsApp API key |
| `SMS_API_URL` | SMS gateway URL |
| `SMS_API_KEY` | SMS API key |
| `AWS_ACCESS_KEY_ID` | AWS credentials |
| `AWS_SECRET_ACCESS_KEY` | AWS credentials |
| `COVID_API_URL` | Legacy COVID reporting API |
| `COVID_API_KEY` | Legacy COVID reporting API key |
| `ELASTIC_APM_DISABLE_SEND` | `true` |

---

## Applying Secrets

Apply a YAML file with base64-encoded values:

```bash
KUBECONFIG=~/.kube/config.badr-dev kubectl apply -f smile-health-secrets.yaml
```

Or patch a single key in an existing secret:

```bash
KUBECONFIG=~/.kube/config.badr-dev kubectl patch secret -n smile-health core-secret \
  --type='json' \
  -p='[{"op":"add","path":"/data/DB_NAME_NOTIFICATION","value":"'$(echo -n "dev_smile_health_notification" | base64)'"}]'
```

After changing secrets, restart the affected deployment:

```bash
KUBECONFIG=~/.kube/config.badr-dev kubectl rollout restart deployment/smile-health-core -n smile-health
```
