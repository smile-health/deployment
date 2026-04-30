# Troubleshooting — smile-health

Issues encountered during initial deployment and their resolutions.

---

## 1. Helm chart missing `envFrom` — secrets not injected into pods

**Symptom**: Pods crash with `[MISSING_ENV_FILE]` from dotenvx; `printenv > .env` produces empty file.

**Cause**: `smile-app-0.1.0.tgz` from chartmuseum does not include `envFrom` in `deployment.yaml`.

**Fix**: Patched chart stored as `smile-app-0.1.0-patched.tgz` in this repo.
The patch adds to `deployment.yaml` before `resources:`:

```yaml
{{- with .Values.app.envFrom }}
envFrom:
  {{- toYaml . | nindent 12 }}
{{- end }}
```

**Always use the patched chart** for smile-health deployments.

---

## 2. Startup command YAML parse error — `unknown escape character`

**Symptom**: Helm upgrade fails parsing the `command` field in values YAML.

**Cause**: Double-quoted YAML strings interpret `\(` as an escape sequence.

**Fix**: Use YAML block literal (`|-`) for commands containing backslashes or special chars:

```yaml
# BAD
command: "cat /context/app/secret | sed 's/\(.*\)/\1/' > .env"

# GOOD
command: |-
  printenv > .env && bun run src/server.ts
```

---

## 3. RabbitMQ wrong namespace — AMQP connection refused

**Symptom**: Backend pods crash with `ECONNREFUSED` connecting to RabbitMQ.

**Cause**: `AMQP_SERVER` pointed to `rabbitmq-management.smile-malawi.svc.cluster.local`
(another namespace). The smile-health namespace has its own RabbitMQ.

**Fix**: Set in `common-secret`:
```
AMQP_SERVER=amqp://devel:<pass>@rabbitmq.smile-health.svc.cluster.local:5672
RABBITMQ_HOST=rabbitmq.smile-health.svc.cluster.local
```

---

## 4. Migration fails — `Table 'dev_smile_health.ws_materials' doesn't exist`

**Symptom**: Main migration `1765877418085_seed-material-targets` fails.

**Cause**: `ws_materials` is a VIEW created by main's seed step, not by a migration.
The migration expects the view to already exist.

**Fix**: Run main **seeds** (which create views) **before** re-running stuck migrations,
or run migrations first — they run until they hit this migration, fail, then run seeds to
create the view, then re-run migrations to complete.

Correct order:
1. `bun src/cli.ts run-migrate` (core)
2. `bun kysely seed:run` (core — creates entity/user data)
3. `bun src/cli.ts run-migrate` (main — may fail partway)
4. `bun kysely seed:run` (main — creates views)
5. `bun src/cli.ts run-migrate` (main again — completes remaining)

---

## 5. `ONLY_FULL_GROUP_BY` SQL errors

**Symptom**: `Internal Server Error: Expression #N of SELECT list is not in GROUP BY clause...`

**Cause**: MySQL 8 enables `ONLY_FULL_GROUP_BY` by default; application queries are not fully
GROUP BY compliant.

**Fix**: Remove `ONLY_FULL_GROUP_BY` from `sql_mode`. Applied via:
- ConfigMap `mysql-config` mounted at `/etc/mysql/conf.d/custom.cnf` (persistent across restarts)
- `SET GLOBAL sql_mode=...` (immediate, runtime only)

After changing global sql_mode, restart backend pods to get fresh connection pools:
```bash
for svc in core main warehouse; do
  KUBECONFIG=~/.kube/config.badr-dev kubectl rollout restart deployment/smile-health-$svc -n smile-health
done
```

---

## 6. `DB_NAME_NOTIFICATION` wrong database

**Symptom**: `/core/notifications/count` returns `Unknown database 'dev_smile_platform_notification'`

**Cause**: `DB_NAME_NOTIFICATION` env var missing from `core-secret`; code defaults to
`dev_smile_platform_notification` (hardcoded in `apps/core/src/config/env.ts`).

**Fix**: Add to `core-secret`:
```bash
KUBECONFIG=~/.kube/config.badr-dev kubectl patch secret -n smile-health core-secret \
  --type='json' \
  -p='[{"op":"add","path":"/data/DB_NAME_NOTIFICATION","value":"'$(echo -n "dev_smile_health_notification" | base64)'"}]'
KUBECONFIG=~/.kube/config.badr-dev kubectl rollout restart deployment/smile-health-core -n smile-health
```

---

## 7. Login returns 401 — Keycloak `invalid_grant`

**Symptom**: `POST /auth/login` returns `{"message":"Invalid username or password","code":401}`
with `invalid_grant: Invalid user credentials` in Keycloak.

**Cause A**: User doesn't exist in MySQL (seeder not run or entity_id mismatch).

**Cause B**: User exists in Keycloak but password doesn't match (stale hash after seed re-run).

**Fix**:
1. Verify user in MySQL: `SELECT id, username, entity_id FROM users WHERE username='admin'`
2. Reset Keycloak password:
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

## 8. PersistentVolume stuck in Released state

**Symptom**: PVC stays Pending after deleting and recreating; PV shows `Released`.

**Cause**: PV retains old `claimRef` after its PVC is deleted.

**Fix**:
```bash
KUBECONFIG=~/.kube/config.badr-dev kubectl patch pv smile-health-mysql-pv \
  -p '{"spec":{"claimRef":null}}'
```

---

## 9. Entity/workspace not found after login

**Symptom**: `/core/entities/:id` returns 500 `no result`; `/core/account/workspaces` returns `[]`.

**Cause**: Seeded user has `entity_id` pointing to a non-existent entity, or
`entity_workspaces` / `user_workspaces` tables are empty.

**Fix**: Re-run core seeds after migrations are complete. The seeds are idempotent and will:
- Ensure entity 37 exists in `entities`
- Assign entity 37 to all active workspaces in `entity_workspaces`
- Assign users (arya, admin) to all active workspaces in `user_workspaces`

```bash
KUBECONFIG=~/.kube/config.badr-dev kubectl exec -n smile-health deploy/smile-health-core -- \
  sh -c "cd /app && printenv > .env && bun kysely seed:run"
```
