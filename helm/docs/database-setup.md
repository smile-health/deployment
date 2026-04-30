# Database Setup — smile-health

## MySQL

### Deployment

StatefulSet `mysql` in `smile-health` namespace using image `mysql:8`.

PV: `smile-health-mysql-pv` — `local-storage` on kube2 at `/mnt/smile-health-mysql` (2Gi).

### Databases

| Database | Owner | Purpose |
|----------|-------|---------|
| `dev_smile_health` | devel | Main application DB (core + main + warehouse + sync queries) |
| `dev_smile_health_mapping` | devel | Sync service mapping tables |
| `dev_smile_health_notification` | devel | Notification service (Sequelize) |

### Users

| User | Password | Host | Grants |
|------|----------|------|--------|
| `root` | `niatikhla5` | `localhost` | ALL |
| `devel` | `niatikhla5` | `%` | ALL on all three DBs |

Grant commands (run as root):
```sql
GRANT ALL PRIVILEGES ON dev_smile_health.* TO 'devel'@'%';
GRANT ALL PRIVILEGES ON dev_smile_health_mapping.* TO 'devel'@'%';
GRANT ALL PRIVILEGES ON dev_smile_health_notification.* TO 'devel'@'%';
FLUSH PRIVILEGES;
```

### sql_mode ConfigMap

MySQL 8 defaults include `ONLY_FULL_GROUP_BY` which breaks several application queries.
A ConfigMap disables it permanently:

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

The ConfigMap is mounted into the StatefulSet at `/etc/mysql/conf.d/custom.cnf`.

To apply at runtime without restart:
```bash
KUBECONFIG=~/.kube/config.badr-dev kubectl exec -n smile-health statefulset/mysql -- \
  mysql -u root -p<root_password> -e \
  "SET GLOBAL sql_mode='STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION'"
```

---

## Redis

StatefulSet `redis` using image `redis:latest`.

Service name: `redis-master.smile-health.svc.cluster.local:6379`

PV: `smile-health-redis-pv` — `local-storage` on kube2 at `/mnt/smile-health-redis` (1Gi).

---

## RabbitMQ

StatefulSet `rabbitmq` via Bitnami helm chart (`bitnami/rabbitmq:4.0.9-debian-12-r1`).

Service name: `rabbitmq.smile-health.svc.cluster.local:5672`

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
KUBECONFIG=~/.kube/config.badr-dev kubectl exec -n smile-health deploy/smile-health-sync -- \
  sh -c "cd /app && printenv > .env && bun -e \"import { runMigrations } from './src/common/infrastructure/database/index.ts'; runMigrations()\""
```

### Notification (Sequelize — already migrated on fresh DB init)
Migrations tracked in `dev_smile_health_notification.SequelizeMeta`.
The image does not bundle `sequelize-cli`; run via the Sequelize API if needed.

---

## Seed Commands

### Core seeds (users, roles, entities, workspaces, materials, etc.)
```bash
KUBECONFIG=~/.kube/config.badr-dev kubectl exec -n smile-health deploy/smile-health-core -- \
  sh -c "cd /app && printenv > .env && bun kysely seed:run"
```

Seeds are idempotent — they use `ON DUPLICATE KEY UPDATE` or pre-check existence.

### Main seeds (creates SQL VIEWs: ws_materials, ws_entities, ws_manufactures, etc.)
```bash
KUBECONFIG=~/.kube/config.badr-dev kubectl exec -n smile-health deploy/smile-health-main -- \
  sh -c "cd /app && printenv > .env && bun kysely seed:run"
```

> Main's "seeds" folder actually contains VIEW definitions that aggregate core tables.
> They must run after both core migrations and core seeds.

---

## Key Tables

### `ws_materials` (VIEW in dev_smile_health)
Created by main seed `1735292913197_create-ws-materials`.
Aggregates `material_workspaces` + `materials` + related tables.
Referenced by many main migrations for seeding vaccine/material data.

### `ws_entities` (VIEW in dev_smile_health)
Created by main seed `1735293161706_create-ws-entities`.
Aggregates `entity_workspaces` + `entities` + `entity_tags`.
Used by core notification queries and other reports.

### `entity_workspaces`
Links entities to programs. Populated by the `entities_seed` in core.
No unique constraint — seed guards against duplicates via pre-check.

### `user_workspaces`
Links users to programs. Populated by the `users_seed` in core.
No unique constraint — seed guards against duplicates via pre-check.
