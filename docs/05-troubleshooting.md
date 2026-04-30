# Troubleshooting — smile-health

Issues encountered during initial deployment and their resolutions.

---

## 1. Pods crash with `[MISSING_ENV_FILE]` — envFrom not in chart

**Symptom**: All backend pods crash on startup. Logs show dotenvx cannot find `.env`.
`printenv > .env` inside the container produces an empty file.

**Cause**: The original `smile-app-0.1.0.tgz` from chartmuseum does not include `envFrom`
in `deployment.yaml`. Without it, Kubernetes secrets are not injected as environment variables.

**Fix**: Use the patched chart at `helm/smile-app-0.1.0-patched.tgz`.
The patch adds to `deployment.yaml` before `resources:`:

```yaml
{{- with .Values.app.envFrom }}
envFrom:
  {{- toYaml . | nindent 12 }}
{{- end }}
```

All values files reference secrets via:

```yaml
app:
  envFrom:
    - secretRef:
        name: common-secret
    - secretRef:
        name: core-secret
```

**Always use the patched chart** for smile-health deployments.

---

## 2. Helm fails with `unknown escape character` in command field

**Symptom**: `helm upgrade` fails to parse the values YAML with an escape sequence error.

**Cause**: Double-quoted YAML strings interpret backslash sequences. Commands with `\(` or other
special characters break parsing.

**Fix**: Use YAML block literal (`|-`) for all command values:

```yaml
# BAD
command: "cat /secret | sed 's/\(.*\)/\1/' > .env"

# GOOD
command: |-
  printenv > .env && bun run src/server.ts
```

---

## 3. RabbitMQ connection refused — wrong namespace FQDN

**Symptom**: Backend pods crash with `ECONNREFUSED` connecting to RabbitMQ.

**Cause**: `AMQP_SERVER` or `RABBITMQ_HOST` pointed to `rabbitmq.smile-malawi.svc.cluster.local`
(another project's namespace). smile-health has its own RabbitMQ.

**Fix**: Ensure secrets use the correct FQDN:

```
AMQP_SERVER=amqp://devel:<pass>@rabbitmq.smile-health.svc.cluster.local:5672
RABBITMQ_HOST=rabbitmq.smile-health.svc.cluster.local
```

---

## 4. Main migration fails — `Table 'dev_smile_health.ws_materials' doesn't exist`

**Symptom**: Migration `1765877418085_seed-material-targets` fails with table not found.

**Cause**: `ws_materials` is a SQL VIEW created by main's seed step (`bun kysely seed:run`),
not by any migration. The migration queries this VIEW but it doesn't exist yet.

**Fix**: Run migrations and seeds in the correct order:

1. `bun src/cli.ts run-migrate` (core)
2. `bun kysely seed:run` (core)
3. `bun src/cli.ts run-migrate` (main — runs until it hits the failing migration)
4. `bun kysely seed:run` (main — creates `ws_materials` and other VIEWs)
5. `bun src/cli.ts run-migrate` (main again — completes remaining migrations)

See `docs/03-database-setup.md` for full commands.

---

## 5. `ONLY_FULL_GROUP_BY` errors on API endpoints

**Symptom**: Multiple endpoints return `Internal Server Error`:
`Expression #N of SELECT list is not in GROUP BY clause...`

**Cause**: MySQL 8 enables `ONLY_FULL_GROUP_BY` by default. Application queries are not
fully GROUP BY compliant.

**Fix**: Remove `ONLY_FULL_GROUP_BY` from `sql_mode`.

Runtime fix (immediate, survives without MySQL restart):

```bash
KUBECONFIG=~/.kube/config.badr-dev kubectl exec -n smile-health statefulset/mysql -- \
  mysql -u root -pniatikhla5 -e \
  "SET GLOBAL sql_mode='STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION'"
```

Persistent fix: ConfigMap `mysql-config` mounted at `/etc/mysql/conf.d/custom.cnf` (see `docs/03-database-setup.md`).

After changing sql_mode, restart backend pods to get fresh connection pools:

```bash
for svc in core main warehouse; do
  KUBECONFIG=~/.kube/config.badr-dev kubectl rollout restart deployment/smile-health-$svc -n smile-health
done
```

---

## 6. `/core/notifications/count` — Unknown database `dev_smile_platform_notification`

**Symptom**: `Unknown database 'dev_smile_platform_notification'` on notification count endpoint.

**Cause**: `DB_NAME_NOTIFICATION` key missing from `core-secret`. The code at
`apps/core/src/config/env.ts` falls back to a hardcoded default `dev_smile_platform_notification`.

**Fix**:

```bash
KUBECONFIG=~/.kube/config.badr-dev kubectl patch secret -n smile-health core-secret \
  --type='json' \
  -p='[{"op":"add","path":"/data/DB_NAME_NOTIFICATION","value":"'$(echo -n "dev_smile_health_notification" | base64)'"}]'

KUBECONFIG=~/.kube/config.badr-dev kubectl rollout restart deployment/smile-health-core -n smile-health
```

---

## 7. Login returns 401 — Keycloak `invalid_grant`

**Symptom**: `POST /auth/login` returns `{"message":"Invalid username or password","code":401}`.
Keycloak logs show `invalid_grant: Invalid user credentials`.

**Cause A**: User doesn't exist in MySQL — core seeds not run, or run with wrong entity_id.

**Cause B**: Keycloak user exists but password doesn't match MySQL bcrypt hash (happens after
re-running seeds with a different password hash, or after resetting the hash without updating
Keycloak).

**Fix**:

1. Verify user exists in MySQL:
```bash
KUBECONFIG=~/.kube/config.badr-dev kubectl exec -n smile-health statefulset/mysql -- \
  mysql -u devel -pniatikhla5 dev_smile_health -e \
  "SELECT id, username, entity_id, role FROM users WHERE username IN ('arya','admin')"
```

2. Reset Keycloak password to match:
```bash
TOKEN=$(curl -s -X POST "https://keycloak.badr.co.id/realms/master/protocol/openid-connect/token" \
  -d "client_id=admin-cli&username=admin&password=keycloak&grant_type=password" \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['access_token'])")

USER_ID=$(curl -s -H "Authorization: Bearer $TOKEN" \
  "https://keycloak.badr.co.id/admin/realms/smile/users?username=admin&exact=true" \
  | python3 -c "import sys,json; print(json.load(sys.stdin)[0]['id'])")

curl -s -X PUT -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  "https://keycloak.badr.co.id/admin/realms/smile/users/$USER_ID/reset-password" \
  -d '{"type":"password","value":"Admin1234!","temporary":false}'
```

---

## 8. Entity not found after login — `/core/entities/:id` returns 500

**Symptom**: After login, frontend calls `/core/entities/35973` and gets 500 `no result`.

**Cause**: Seeded user has `entity_id` pointing to a non-existent entity. The original seed
used entity_id=35973 (from another environment). smile-health only has entity id=37.

**Fix**: The seed now uses `entity_id: 37`. If users were already inserted with the wrong
entity_id, patch directly:

```bash
KUBECONFIG=~/.kube/config.badr-dev kubectl exec -n smile-health statefulset/mysql -- \
  mysql -u devel -pniatikhla5 dev_smile_health -e \
  "UPDATE users SET entity_id=37 WHERE username IN ('arya','admin')"
```

---

## 9. `/core/account/workspaces` returns empty array

**Symptom**: After login, workspace/program list is empty. Frontend shows no programs.

**Cause**: `entity_workspaces` or `user_workspaces` tables are empty.
Both tables have no unique constraints — duplicate rows can be inserted on seed re-runs.

**Fix**: Re-run core seeds. They pre-check for existing rows:

```bash
KUBECONFIG=~/.kube/config.badr-dev kubectl exec -n smile-health deploy/smile-health-core -- \
  sh -c "cd /app && printenv > .env && bun kysely seed:run"
```

If rows are duplicated (28 rows instead of 14), clean them up:

```bash
# Remove duplicate user_workspaces (keep the row with the lowest id)
KUBECONFIG=~/.kube/config.badr-dev kubectl exec -n smile-health statefulset/mysql -- \
  mysql -u devel -pniatikhla5 dev_smile_health -e "
    DELETE uw1 FROM user_workspaces uw1
    INNER JOIN user_workspaces uw2
    WHERE uw1.user_id = uw2.user_id
      AND uw1.workspace_id = uw2.workspace_id
      AND uw1.id > uw2.id"
```

---

## 10. PersistentVolume stuck in Released state

**Symptom**: PVC stays Pending after deleting and recreating. PV shows status `Released`.

**Cause**: PV retains old `claimRef` after its PVC is deleted.

**Fix**:

```bash
KUBECONFIG=~/.kube/config.badr-dev kubectl patch pv smile-health-mysql-pv \
  -p '{"spec":{"claimRef":null}}'
```

Repeat for redis or rabbitmq PVs as needed.

---

## 11. Sync service `run-migrate` command not found

**Symptom**: Running `bun src/cli.ts run-migrate` on the sync service exits with command not found.

**Cause**: The sync service CLI does not expose a `run-migrate` command. `runMigrations()` exists
in `src/common/infrastructure/database/index.ts` but is not wired to the CLI.

**Fix**: Call `runMigrations()` directly:

```bash
KUBECONFIG=~/.kube/config.badr-dev kubectl exec -n smile-health deploy/smile-health-sync-service -- \
  sh -c "cd /app && printenv > .env && bun -e \"import { runMigrations } from './src/common/infrastructure/database/index.ts'; runMigrations()\""
```
