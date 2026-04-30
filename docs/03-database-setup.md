# Database Setup — smile-health

## MySQL

### Deployment

StatefulSet `mysql` in `smile-health` namespace using image `mysql:8`.  
PV: `smile-health-mysql-pv` — `local-storage` on kube2 at `/mnt/smile-health-mysql` (2Gi).

### Databases

| Database | Used By | Purpose |
|----------|---------|---------|
| `dev_smile_health` | core, main, warehouse | Main application data |
| `dev_smile_health_mapping` | sync | Sync service mapping tables |
| `dev_smile_health_notification` | notification | Notification service (Sequelize) |

### Users

| User | Password | Host | Grants |
|------|----------|------|--------|
| `root` | `niatikhla5` | `localhost` | ALL |
| `devel` | `niatikhla5` | `%` | ALL on all three DBs |

```sql
GRANT ALL PRIVILEGES ON dev_smile_health.* TO 'devel'@'%';
GRANT ALL PRIVILEGES ON dev_smile_health_mapping.* TO 'devel'@'%';
GRANT ALL PRIVILEGES ON dev_smile_health_notification.* TO 'devel'@'%';
FLUSH PRIVILEGES;
```

### sql_mode — ONLY_FULL_GROUP_BY

MySQL 8 enables `ONLY_FULL_GROUP_BY` by default. Many application queries are not fully
GROUP BY compliant, causing `Expression #N of SELECT list is not in GROUP BY clause` errors.

This is disabled permanently via ConfigMap mounted at `/etc/mysql/conf.d/custom.cnf`:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: mysql-config
  namespace: smile-health
data:
  my.cnf: |
    [mysqld]
    sql_mode=STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION
```

To apply at runtime without restarting MySQL:

```bash
KUBECONFIG=~/.kube/config.badr-dev kubectl exec -n smile-health statefulset/mysql -- \
  mysql -u root -pniatikhla5 -e \
  "SET GLOBAL sql_mode='STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION'"
```

After changing sql_mode, restart backend pods to clear connection pools:

```bash
for svc in core main warehouse; do
  KUBECONFIG=~/.kube/config.badr-dev kubectl rollout restart deployment/smile-health-$svc -n smile-health
done
```

---

## Redis

StatefulSet `redis` using image `redis:latest`.  
Service: `redis-master.smile-health.svc.cluster.local:6379`  
PV: `smile-health-redis-pv` — `local-storage` on kube2 at `/mnt/smile-health-redis` (1Gi).

---

## RabbitMQ

Deployed via Bitnami helm chart (`bitnami/rabbitmq`, tag `4.0.9-debian-12-r1`).  
Service: `rabbitmq.smile-health.svc.cluster.local:5672`  
AMQP URL: `amqp://devel:<password>@rabbitmq.smile-health.svc.cluster.local:5672`  
PV: `smile-health-rabbitmq-pv` — `local-storage` on kube2 at `/mnt/smile-health-rabbitmq` (1Gi).

---

## Migration Commands

### Core (Kysely)

```bash
KUBECONFIG=~/.kube/config.badr-dev kubectl exec -n smile-health deploy/smile-health-core -- \
  sh -c "cd /app && printenv > .env && bun src/cli.ts run-migrate"
```

### Main (Kysely)

```bash
KUBECONFIG=~/.kube/config.badr-dev kubectl exec -n smile-health deploy/smile-health-main -- \
  sh -c "cd /app && printenv > .env && bun src/cli.ts run-migrate"
```

### Sync (Kysely — no CLI command, call directly)

```bash
KUBECONFIG=~/.kube/config.badr-dev kubectl exec -n smile-health deploy/smile-health-sync-service -- \
  sh -c "cd /app && printenv > .env && bun -e \"import { runMigrations } from './src/common/infrastructure/database/index.ts'; runMigrations()\""
```

The sync service has no `run-migrate` CLI command — `runMigrations()` must be called directly.

### Notification (Sequelize)

Notification migrations are tracked in `dev_smile_health_notification.SequelizeMeta`.
They run automatically on service startup for a fresh database. Check status:

```bash
KUBECONFIG=~/.kube/config.badr-dev kubectl exec -n smile-health statefulset/mysql -- \
  mysql -u devel -pniatikhla5 -e "SELECT name FROM dev_smile_health_notification.SequelizeMeta"
```

---

## Seed Commands

### Core seeds

Creates users, roles, entities, workspaces, `entity_workspaces`, `user_workspaces`.
Seeds are idempotent — they pre-check for existing rows before inserting.

```bash
KUBECONFIG=~/.kube/config.badr-dev kubectl exec -n smile-health deploy/smile-health-core -- \
  sh -c "cd /app && printenv > .env && bun kysely seed:run"
```

### Main seeds

Creates SQL VIEWs: `ws_materials`, `ws_entities`, `ws_manufactures`, etc.
These aggregate core data tables and must exist before some main migrations run.

```bash
KUBECONFIG=~/.kube/config.badr-dev kubectl exec -n smile-health deploy/smile-health-main -- \
  sh -c "cd /app && printenv > .env && bun kysely seed:run"
```

---

## Key Tables and Views

### `ws_materials` (VIEW in dev_smile_health)

Created by main seed `1735292913197_create-ws-materials`.  
Aggregates `material_workspaces` + `materials` + related tables.  
Referenced by migration `1765877418085_seed-material-targets` and many other main migrations.  
**Must exist before running the full set of main migrations.**

### `ws_entities` (VIEW in dev_smile_health)

Created by main seed `1735293161706_create-ws-entities`.  
Aggregates `entity_workspaces` + `entities` + `entity_tags`.  
Used by core notification queries and reports.

### `entity_workspaces`

Links entities to programs/workspaces. Populated by core's `entities_seed`.  
No unique constraint — seeds guard against duplicates with a pre-existence check.

### `user_workspaces`

Links users to programs/workspaces. Populated by core's `users_seed`.  
No unique constraint — seeds guard against duplicates with a pre-existence check.

---

## Seeded Entity

| Field | Value |
|-------|-------|
| ID | 37 |
| Code | 1031151 |
| Name | PUSKESMAS BOGOR SELATAN |
| Type | 3 |
| Province | 32 (Jawa Barat) |
| Regency | 3271 (Kota Bogor) |

All seeded users have `entity_id = 37`. If this entity does not exist in `entities`,
`/core/entities/:id` returns 500 `no result` and the frontend fails to load.

---

## Active Programs (Workspaces)

All seeded users and entity 37 are assigned to these 14 programs via `entity_workspaces`
and `user_workspaces`:

| ID | Key | Name |
|----|-----|------|
| 1 | dengue_beneficiaries | DENGUE |
| 2 | immunization_beneficiaries | IMUNISASI |
| 3 | malaria | MALARIA |
| 4 | tb | TB |
| 5 | hiv | HIV |
| 9 | bmhp-skrining | PKG |
| 12 | hepatitis | HEPATITIS |
| 13 | keswa | KESEHATAN JIWA |
| 14 | frambusia | FRAMBUSIA |
| 15 | filariasis | FILARIASIS |
| 16 | diare | DIARE |
| 17 | kusta | KUSTA |
| 18 | kesga | KESEHATAN KELUARGA |
| 19 | kesling | KESEHATAN LINGKUNGAN |

If `entity_workspaces` or `user_workspaces` are empty, `/core/account/workspaces` returns `[]`
and the frontend shows no programs after login. Re-run core seeds to fix.
