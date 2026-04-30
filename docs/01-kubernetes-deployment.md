# Kubernetes Deployment Guide — smile-health

Full step-by-step guide to deploy smile-health to the `smile-health` namespace on badr-dev from scratch.

**Domain**: https://smile-health.badr.co.id  
**Cluster**: badr-dev  
**Kube node IP**: 10.10.0.10  
**Namespace**: `smile-health`  
**Kubeconfig**: `~/.kube/config.badr-dev`

---

## Architecture Overview

```
Internet → smile-health.badr.co.id
  → Nginx reverse proxy (10.10.0.3:443)
      /home/devel/docker/webserver/conf/smile-health.conf
  → Kube ingress node (10.10.0.10:80)
  → Istio IngressGateway (istio-system/badr-gateway)
  → VirtualService (smile-health-vs, namespace: smile-health)
      /auth/*                → smile-health-auth-service:80
      /core/*                → smile-health-core:80
      /main/*, /account/*    → smile-health-main:80
      /warehouse-report/*    → smile-health-warehouse-service:80
      /sync/*                → smile-health-sync-service:80
      /notification/*        → smile-health-notification:80
      /*                     → smile-health-frontend:80
```

**Infrastructure** (in-cluster, namespace `smile-health`):
- MySQL 8 — StatefulSet, PV on kube2 at `/mnt/smile-health-mysql`
- Redis — StatefulSet, PV on kube2 at `/mnt/smile-health-redis`
- RabbitMQ — Bitnami Helm chart, PV on kube2 at `/mnt/smile-health-rabbitmq`

**Helm**: All app services use `smile-app-0.1.0-patched.tgz` (shared chart patched to add `envFrom`). See `helm/` directory.

---

## Prerequisites

- `kubectl` configured with `KUBECONFIG=~/.kube/config.badr-dev`
- `helm` v3
- SSH access to kube2 (10.10.0.11) — for creating PV directories
- SSH access to 10.10.0.3 port 60322 — nginx reverse proxy
- Keycloak admin credentials (see `docs/04-credentials.md`)
- GitHub PAT with `read:packages` scope — for pulling GHCR images

---

## Step 1 — Create Namespace

```bash
KUBECONFIG=~/.kube/config.badr-dev kubectl create namespace smile-health
```

---

## Step 2 — Create PersistentVolume Directories on kube2

SSH to kube2 and create the mount directories:

```bash
ssh devel@10.10.0.11
sudo mkdir -p /mnt/smile-health-mysql /mnt/smile-health-redis /mnt/smile-health-rabbitmq
sudo chmod 777 /mnt/smile-health-mysql /mnt/smile-health-redis /mnt/smile-health-rabbitmq
exit
```

Apply PV manifests:

```bash
KUBECONFIG=~/.kube/config.badr-dev kubectl apply -f - <<'EOF'
apiVersion: v1
kind: PersistentVolume
metadata:
  name: smile-health-mysql-pv
spec:
  capacity:
    storage: 2Gi
  accessModes: [ReadWriteOnce]
  persistentVolumeReclaimPolicy: Retain
  storageClassName: local-storage
  local:
    path: /mnt/smile-health-mysql
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values: [kube2]
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: smile-health-redis-pv
spec:
  capacity:
    storage: 1Gi
  accessModes: [ReadWriteOnce]
  persistentVolumeReclaimPolicy: Retain
  storageClassName: local-storage
  local:
    path: /mnt/smile-health-redis
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values: [kube2]
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: smile-health-rabbitmq-pv
spec:
  capacity:
    storage: 1Gi
  accessModes: [ReadWriteOnce]
  persistentVolumeReclaimPolicy: Retain
  storageClassName: local-storage
  local:
    path: /mnt/smile-health-rabbitmq
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values: [kube2]
EOF
```

---

## Step 3 — Create GHCR Image Pull Secret

Images are hosted on GitHub Container Registry (`ghcr.io/smile-health/*`).

```bash
KUBECONFIG=~/.kube/config.badr-dev kubectl create secret docker-registry ghcr-secret \
  --namespace smile-health \
  --docker-server=ghcr.io \
  --docker-username=<github-username> \
  --docker-password=<github-pat-with-packages-read>
```

---

## Step 4 — Create Kubernetes Secrets

See `docs/02-secrets-reference.md` for the full list of keys per secret.

All secrets must exist in the `smile-health` namespace before deploying services.
Required secrets: `common-secret`, `auth-secret`, `core-secret`, `main-secret`,
`warehouse-secret`, `sync-secret`, `notification-secret`.

Example for `common-secret`:

```bash
KUBECONFIG=~/.kube/config.badr-dev kubectl create secret generic common-secret \
  --namespace smile-health \
  --from-literal=DB_HOST=mysql.smile-health.svc.cluster.local \
  --from-literal=DB_PORT=3306 \
  --from-literal=DB_NAME=dev_smile_health \
  --from-literal=DB_USER=devel \
  --from-literal=DB_PASSWORD=niatikhla5 \
  --from-literal=DB_NAME_NOTIFICATION=dev_smile_health_notification \
  --from-literal=RABBITMQ_HOST=rabbitmq.smile-health.svc.cluster.local \
  --from-literal=RABBITMQ_PORT=5672 \
  --from-literal=RABBITMQ_USERNAME=devel \
  --from-literal=RABBITMQ_PASSWORD=niatikhla5 \
  --from-literal=AMQP_SERVER=amqp://devel:niatikhla5@rabbitmq.smile-health.svc.cluster.local:5672 \
  --from-literal=REDIS_HOST=redis-master.smile-health.svc.cluster.local \
  --from-literal=REDIS_PORT=6379 \
  --from-literal=NODE_ENV=development \
  --from-literal=APP_URL=https://smile-health.badr.co.id \
  --from-literal=FRONTEND_URL=https://smile-health.badr.co.id \
  --from-literal=AUTH_URL=https://smile-health.badr.co.id/auth \
  --from-literal=CORE_API_URL=https://smile-health.badr.co.id/core \
  --from-literal=USER_SERVICE_SERVER_URL=https://smile-health.badr.co.id/core
```

---

## Step 5 — Deploy MySQL

```bash
KUBECONFIG=~/.kube/config.badr-dev kubectl apply -n smile-health -f - <<'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: mysql-config
  namespace: smile-health
data:
  my.cnf: |
    [mysqld]
    sql_mode=STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION
---
apiVersion: v1
kind: Service
metadata:
  name: mysql
  namespace: smile-health
spec:
  selector:
    app: mysql
  ports:
  - port: 3306
    targetPort: 3306
  clusterIP: None
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: mysql
  namespace: smile-health
spec:
  serviceName: mysql
  replicas: 1
  selector:
    matchLabels:
      app: mysql
  template:
    metadata:
      labels:
        app: mysql
    spec:
      containers:
      - name: mysql
        image: mysql:8
        env:
        - name: MYSQL_ROOT_PASSWORD
          value: niatikhla5
        - name: MYSQL_DATABASE
          value: dev_smile_health
        - name: MYSQL_USER
          value: devel
        - name: MYSQL_PASSWORD
          value: niatikhla5
        ports:
        - containerPort: 3306
        volumeMounts:
        - name: mysql-data
          mountPath: /var/lib/mysql
        - name: mysql-config
          mountPath: /etc/mysql/conf.d/custom.cnf
          subPath: my.cnf
          readOnly: true
      volumes:
      - name: mysql-config
        configMap:
          name: mysql-config
  volumeClaimTemplates:
  - metadata:
      name: mysql-data
    spec:
      accessModes: [ReadWriteOnce]
      storageClassName: local-storage
      resources:
        requests:
          storage: 2Gi
EOF
```

Wait for MySQL to be ready, then create additional databases:

```bash
KUBECONFIG=~/.kube/config.badr-dev kubectl wait pod/mysql-0 -n smile-health \
  --for=condition=Ready --timeout=120s

KUBECONFIG=~/.kube/config.badr-dev kubectl exec -n smile-health statefulset/mysql -- \
  mysql -u root -pniatikhla5 -e "
    CREATE DATABASE IF NOT EXISTS dev_smile_health_mapping;
    CREATE DATABASE IF NOT EXISTS dev_smile_health_notification;
    GRANT ALL PRIVILEGES ON dev_smile_health.* TO 'devel'@'%';
    GRANT ALL PRIVILEGES ON dev_smile_health_mapping.* TO 'devel'@'%';
    GRANT ALL PRIVILEGES ON dev_smile_health_notification.* TO 'devel'@'%';
    FLUSH PRIVILEGES;
  "
```

**Why the ConfigMap matters**: MySQL 8 enables `ONLY_FULL_GROUP_BY` by default. Many application
queries are not fully GROUP BY compliant and will return 500 errors without disabling it.
The ConfigMap applies the restriction permanently; without it you'd need `SET GLOBAL sql_mode=...`
after every MySQL restart.

---

## Step 6 — Deploy Redis

```bash
KUBECONFIG=~/.kube/config.badr-dev kubectl apply -n smile-health -f - <<'EOF'
apiVersion: v1
kind: Service
metadata:
  name: redis-master
  namespace: smile-health
spec:
  selector:
    app: redis
  ports:
  - port: 6379
    targetPort: 6379
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: redis
  namespace: smile-health
spec:
  serviceName: redis-master
  replicas: 1
  selector:
    matchLabels:
      app: redis
  template:
    metadata:
      labels:
        app: redis
    spec:
      containers:
      - name: redis
        image: redis:latest
        ports:
        - containerPort: 6379
        volumeMounts:
        - name: redis-data
          mountPath: /data
  volumeClaimTemplates:
  - metadata:
      name: redis-data
    spec:
      accessModes: [ReadWriteOnce]
      storageClassName: local-storage
      resources:
        requests:
          storage: 1Gi
EOF
```

---

## Step 7 — Deploy RabbitMQ

```bash
helm repo add bitnami https://charts.bitnami.com/bitnami

KUBECONFIG=~/.kube/config.badr-dev helm upgrade --install rabbitmq bitnami/rabbitmq \
  --namespace smile-health \
  --set image.tag=4.0.9-debian-12-r1 \
  --set auth.username=devel \
  --set auth.password=niatikhla5 \
  --set persistence.enabled=true \
  --set persistence.storageClass=local-storage \
  --set persistence.size=1Gi
```

**Note**: RabbitMQ must be in the **same namespace** as the backend services.
Early deployments pointed to `rabbitmq.smile-malawi.svc.cluster.local` — pods crashed with
`ECONNREFUSED`. Always use `rabbitmq.smile-health.svc.cluster.local`.

---

## Step 8 — Deploy Application Services

The deploy script handles all services in the correct order:

```bash
cd /path/to/deployment/helm
./smile-health-deploy.sh all
```

Or deploy individual services:

```bash
./smile-health-deploy.sh auth
./smile-health-deploy.sh core
./smile-health-deploy.sh main
./smile-health-deploy.sh warehouse
./smile-health-deploy.sh sync
./smile-health-deploy.sh notification
./smile-health-deploy.sh frontend
./smile-health-deploy.sh vs      # applies VirtualService
```

The script uses `helm upgrade --install` so it's safe to re-run.

**About the patched chart**: The standard `smile-app-0.1.0.tgz` from chartmuseum does not include
`envFrom` in the deployment template. Without `envFrom`, Kubernetes secrets are not injected as
environment variables and `printenv > .env` produces an empty file, causing all pods to crash
with `[MISSING_ENV_FILE]`. The patched chart at `helm/smile-app-0.1.0-patched.tgz` adds:

```yaml
{{- with .Values.app.envFrom }}
envFrom:
  {{- toYaml . | nindent 12 }}
{{- end }}
```

**About startup commands**: Each service values file sets `app.image.command` using YAML block
literal (`|-`) to avoid escape sequence errors with special characters. The pattern is:

```yaml
command: |-
  printenv > .env && bun run src/server.ts
```

This writes all injected env vars to `.env` before starting the server (dotenvx expects `.env`).

---

## Step 9 — Apply VirtualService

```bash
KUBECONFIG=~/.kube/config.badr-dev kubectl apply -f \
  helm/backend/virtualservice/vs-smile-health-dev-onprem.yml
```

Verify:

```bash
KUBECONFIG=~/.kube/config.badr-dev kubectl get virtualservice -n smile-health
```

---

## Step 10 — Configure Nginx Reverse Proxy

SSH to the nginx server and create the virtualhost config:

```bash
sshpass -p "niatikhla5" ssh -p 60322 devel@10.10.0.3
```

Create `/home/devel/docker/webserver/conf/smile-health.conf`:

```nginx
server {
    server_name smile-health.badr.co.id;
    listen 80;
    location / {
        return 301 https://$host$request_uri;
    }
}

server {
    server_name smile-health.badr.co.id;
    listen 443 ssl;
    listen [::]:443 ssl;

    ssl_certificate /ssl/badr.co.id.pem;
    ssl_certificate_key /ssl/badr.co.id.key;

    location / {
        proxy_pass http://10.10.0.10;
        proxy_http_version 1.1;
    }

    proxy_buffers 32 4m;
    proxy_busy_buffers_size 25m;
    proxy_buffer_size 512k;
    proxy_ignore_headers "Cache-Control" "Expires";
    proxy_max_temp_file_size 0;

    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;

    client_max_body_size 1024m;
    client_body_buffer_size 4m;

    proxy_connect_timeout 600;
    proxy_read_timeout 600;
    proxy_send_timeout 600;
    send_timeout 600;

    proxy_intercept_errors off;
}
```

Reload nginx:

```bash
docker exec webserver nginx -s reload
```

---

## Step 11 — Run Database Migrations and Seeds

Wait for all pods to be Running:

```bash
KUBECONFIG=~/.kube/config.badr-dev kubectl get pods -n smile-health
```

### Order is critical — follow exactly

**1. Core migrations**

```bash
KUBECONFIG=~/.kube/config.badr-dev kubectl exec -n smile-health deploy/smile-health-core -- \
  sh -c "cd /app && printenv > .env && bun src/cli.ts run-migrate"
```

**2. Core seeds** (creates users, roles, entities, workspaces, entity_workspaces, user_workspaces)

```bash
KUBECONFIG=~/.kube/config.badr-dev kubectl exec -n smile-health deploy/smile-health-core -- \
  sh -c "cd /app && printenv > .env && bun kysely seed:run"
```

**3. Main migrations** (will run partially, may fail on `seed-material-targets` — that's expected)

```bash
KUBECONFIG=~/.kube/config.badr-dev kubectl exec -n smile-health deploy/smile-health-main -- \
  sh -c "cd /app && printenv > .env && bun src/cli.ts run-migrate"
```

**4. Main seeds** (creates SQL VIEWs: `ws_materials`, `ws_entities`, `ws_manufactures`, etc.)

```bash
KUBECONFIG=~/.kube/config.badr-dev kubectl exec -n smile-health deploy/smile-health-main -- \
  sh -c "cd /app && printenv > .env && bun kysely seed:run"
```

**5. Main migrations again** (completes remaining migrations that depend on VIEWs from step 4)

```bash
KUBECONFIG=~/.kube/config.badr-dev kubectl exec -n smile-health deploy/smile-health-main -- \
  sh -c "cd /app && printenv > .env && bun src/cli.ts run-migrate"
```

**6. Sync migrations**

```bash
KUBECONFIG=~/.kube/config.badr-dev kubectl exec -n smile-health deploy/smile-health-sync-service -- \
  sh -c "cd /app && printenv > .env && bun -e \"import { runMigrations } from './src/common/infrastructure/database/index.ts'; runMigrations()\""
```

**Why this order**: `ws_materials` is a SQL VIEW created by main's seed step, not a table created
by a migration. Migration `1765877418085_seed-material-targets` queries this VIEW. Running all
main migrations before the VIEW exists causes a fatal error. The VIEW must exist before that
migration runs.

**Notification**: Sequelize migrations run automatically on service start. No manual step needed.

---

## Step 12 — Verify Keycloak Users

On first login, the auth service creates the Keycloak user automatically. But if users were
seeded directly into MySQL, their passwords must match Keycloak.

Check and reset if needed:

```bash
TOKEN=$(curl -s -X POST "https://keycloak.badr.co.id/realms/master/protocol/openid-connect/token" \
  -d "client_id=admin-cli&username=admin&password=keycloak&grant_type=password" \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['access_token'])")

for USERNAME in arya admin; do
  USER_ID=$(curl -s -H "Authorization: Bearer $TOKEN" \
    "https://keycloak.badr.co.id/admin/realms/smile/users?username=$USERNAME&exact=true" \
    | python3 -c "import sys,json; d=json.load(sys.stdin); print(d[0]['id'] if d else 'NOT_FOUND')")

  echo "$USERNAME -> $USER_ID"

  if [ "$USER_ID" != "NOT_FOUND" ]; then
    curl -s -X PUT -H "Authorization: Bearer $TOKEN" \
      -H "Content-Type: application/json" \
      "https://keycloak.badr.co.id/admin/realms/smile/users/$USER_ID/reset-password" \
      -d '{"type":"password","value":"Admin1234!","temporary":false}'
    echo "$USERNAME password reset"
  fi
done
```

---

## Step 13 — Verification

```bash
# All pods running
KUBECONFIG=~/.kube/config.badr-dev kubectl get pods -n smile-health

# Login
RESP=$(curl -s -X POST https://smile-health.badr.co.id/auth/login \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d 'username=admin&password=Admin1234!&device_type=web')
echo $RESP | python3 -m json.tool

TOKEN=$(echo $RESP | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['access_token'])")

# Core endpoints
curl -s -H "Authorization: Bearer $TOKEN" https://smile-health.badr.co.id/core/account/profile | python3 -m json.tool
curl -s -H "Authorization: Bearer $TOKEN" https://smile-health.badr.co.id/core/account/workspaces | python3 -m json.tool
curl -s -H "Authorization: Bearer $TOKEN" https://smile-health.badr.co.id/core/notifications/count | python3 -m json.tool
```

All should return HTTP 200 with valid JSON.
