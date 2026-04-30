# smile-health Deployment Guide

Complete step-by-step guide to deploy smile-health to a fresh Kubernetes namespace.

**Domain**: https://smile-health.badr.co.id  
**Cluster**: badr-dev (10.10.0.10)  
**Namespace**: `smile-health`  
**Kubeconfig**: `~/.kube/config.badr-dev`

---

## Architecture

```
Internet → smile-health.badr.co.id
  → Nginx reverse proxy (10.10.0.3:443)
      /home/devel/docker/webserver/conf/smile-health.conf
  → Kube node (10.10.0.10:80)
  → Istio IngressGateway (istio-system/badr-gateway)
  → VirtualService (smile-health-vs, namespace: smile-health)
      /auth/*           → smile-health-auth:80
      /main/*, /account/* → smile-health-main:80
      /core/*           → smile-health-core:80
      /warehouse-report/* → smile-health-warehouse:80
      /sync/*           → smile-health-sync:80
      /*                → smile-health-frontend:80
```

---

## Prerequisites

- `kubectl` with `KUBECONFIG=~/.kube/config.badr-dev`
- `helm` v3
- Access to `ghcr.io/smile-health/*` images (ghcr-secret)
- Keycloak admin access at `https://keycloak.badr.co.id` (admin / keycloak)
- SSH access to 10.10.0.3: `sshpass -p "niatikhla5" ssh -p 60322 devel@10.10.0.3`
- SSH access to 10.10.0.11 (kube2) for PV directories
- Helm chart: `smile-app-0.1.0.tgz` (patched — see step 4)

---

## Step 1 — Create Namespace

```bash
KUBECONFIG=~/.kube/config.badr-dev kubectl create namespace smile-health
```

---

## Step 2 — Create PersistentVolumes on kube2

SSH to kube2 and create directories:

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

```bash
KUBECONFIG=~/.kube/config.badr-dev kubectl create secret docker-registry ghcr-secret \
  --namespace smile-health \
  --docker-server=ghcr.io \
  --docker-username=<github-username> \
  --docker-password=<github-pat-with-packages-read>
```

---

## Step 4 — Create Application Secrets

See `secrets-reference.md` for all required keys. Apply your secrets:

```bash
KUBECONFIG=~/.kube/config.badr-dev kubectl apply -f /path/to/smile-health-secrets.yaml
```

Required secrets: `common-secret`, `auth-secret`, `core-secret`, `main-secret`,
`warehouse-secret`, `sync-secret`, `notification-secret`.

Critical values to set correctly:
- `DB_HOST=mysql.smile-health.svc.cluster.local`
- `DB_NAME=dev_smile_health`
- `DB_USER=devel`, `DB_PASSWORD=<password>`
- `DB_NAME_NOTIFICATION=dev_smile_health_notification` (in `core-secret`)
- `RABBITMQ_HOST=rabbitmq.smile-health.svc.cluster.local`
- `REDIS_HOST=redis-master.smile-health.svc.cluster.local`
- `KEYCLOAK_SERVER_URL=https://keycloak.badr.co.id` (in `auth-secret`)
- `KEYCLOAK_REALM=smile`, `KEYCLOAK_CLIENT_ID=smile` (in `auth-secret`)
- `USER_SERVICE_SERVER_URL=https://smile-health.badr.co.id/core` (in `auth-secret`)

---

## Step 5 — Deploy Infrastructure (MySQL, Redis, RabbitMQ)

### MySQL

```bash
KUBECONFIG=~/.kube/config.badr-dev kubectl apply -n smile-health -f - <<'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: mysql-config
data:
  my.cnf: |
    [mysqld]
    sql_mode=STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION
---
apiVersion: v1
kind: Service
metadata:
  name: mysql
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

Wait for MySQL ready, then create additional databases and grant permissions:

```bash
# Wait for pod
KUBECONFIG=~/.kube/config.badr-dev kubectl wait pod/mysql-0 -n smile-health --for=condition=Ready --timeout=120s

# Create databases
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

### Redis

```bash
KUBECONFIG=~/.kube/config.badr-dev kubectl apply -n smile-health -f - <<'EOF'
apiVersion: v1
kind: Service
metadata:
  name: redis-master
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

### RabbitMQ

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

---

## Step 6 — Get the Patched Helm Chart

The standard `smile-app-0.1.0.tgz` from chartmuseum lacks `envFrom` support.
Use the patched version stored in this repo:

```bash
# The patched chart is at helm-values/smile-app-0.1.0-patched.tgz
# It adds envFrom support to the deployment template
CHART=/home/devel/helm-values/smile-app-0.1.0-patched.tgz
```

---

## Step 7 — Deploy Backend Services

```bash
KUBECONFIG=~/.kube/config.badr-dev
CHART=/home/devel/helm-values/smile-app-0.1.0-patched.tgz
NS=smile-health
HV=/home/devel/helm-values

helm upgrade --install smile-health-auth-service $CHART \
  --kubeconfig ~/.kube/config.badr-dev -n $NS \
  -f $HV/backend/smile-health-auth-service-dev-onprem.yaml

helm upgrade --install smile-health-core $CHART \
  --kubeconfig ~/.kube/config.badr-dev -n $NS \
  -f $HV/backend/smile-health-core-dev-onprem.yaml

helm upgrade --install smile-health-main $CHART \
  --kubeconfig ~/.kube/config.badr-dev -n $NS \
  -f $HV/backend/smile-health-main-dev-onprem.yaml

helm upgrade --install smile-health-warehouse-service $CHART \
  --kubeconfig ~/.kube/config.badr-dev -n $NS \
  -f $HV/backend/smile-health-warehouse-service-dev-onprem.yaml

helm upgrade --install smile-health-sync-service $CHART \
  --kubeconfig ~/.kube/config.badr-dev -n $NS \
  -f $HV/backend/smile-health-sync-service-dev-onprem.yaml

helm upgrade --install smile-health-notification $CHART \
  --kubeconfig ~/.kube/config.badr-dev -n $NS \
  -f $HV/backend/smile-health-notification-dev-onprem.yaml
```

---

## Step 8 — Deploy Frontend

```bash
KUBECONFIG=~/.kube/config.badr-dev helm upgrade --install smile-health-frontend \
  /home/devel/helm-values/smile-app-0.1.0-patched.tgz \
  --namespace smile-health \
  -f /home/devel/helm-values/frontend/smile-health-frontend-dev.yaml
```

---

## Step 9 — Apply VirtualService

```bash
KUBECONFIG=~/.kube/config.badr-dev kubectl apply -f \
  /home/devel/helm-values/backend/virtualservice/vs-smile-health-dev-onprem.yml
```

---

## Step 10 — Configure Nginx Virtualhost

SSH to the reverse proxy server:

```bash
sshpass -p "niatikhla5" ssh -p 60322 devel@10.10.0.3
```

The config is at `/home/devel/docker/webserver/conf/smile-health.conf`.
Reload nginx after applying:

```bash
docker exec webserver nginx -s reload
```

---

## Step 11 — Run Database Migrations

Wait for all pods to be running first:

```bash
KUBECONFIG=~/.kube/config.badr-dev kubectl get pods -n smile-health
```

### Core migrations + seeds

```bash
KUBECONFIG=~/.kube/config.badr-dev kubectl exec -n smile-health deploy/smile-health-core -- \
  sh -c "cd /app && printenv > .env && bun src/cli.ts run-migrate"

KUBECONFIG=~/.kube/config.badr-dev kubectl exec -n smile-health deploy/smile-health-core -- \
  sh -c "cd /app && printenv > .env && bun kysely seed:run"
```

### Main migrations + seeds (views)

```bash
KUBECONFIG=~/.kube/config.badr-dev kubectl exec -n smile-health deploy/smile-health-main -- \
  sh -c "cd /app && printenv > .env && bun src/cli.ts run-migrate"

KUBECONFIG=~/.kube/config.badr-dev kubectl exec -n smile-health deploy/smile-health-main -- \
  sh -c "cd /app && printenv > .env && bun kysely seed:run"
```

> **Note**: `bun kysely seed:run` in main creates SQL VIEWs (`ws_materials`, `ws_entities`, etc.)
> that aggregate core data tables. These must run after core migrations.

### Sync migrations

```bash
KUBECONFIG=~/.kube/config.badr-dev kubectl exec -n smile-health deploy/smile-health-sync -- \
  sh -c "cd /app && printenv > .env && bun -e \"import { runMigrations } from './src/common/infrastructure/database/index.ts'; runMigrations()\""
```

### Notification migrations

Notification uses Sequelize. The migrations are already up to date in `dev_smile_health_notification`
when the DB is initialized. If needed:

```bash
# sequelize-cli is not bundled — run via the Sequelize API or copy migrations manually
KUBECONFIG=~/.kube/config.badr-dev kubectl exec -n smile-health statefulset/mysql -- \
  mysql -u devel -p<password> -e "SELECT name FROM dev_smile_health_notification.SequelizeMeta"
```

---

## Step 12 — Register Users in Keycloak

The seeded users (`arya`, `admin`) need Keycloak accounts. On first login via core service,
the Keycloak user is created automatically IF the user already exists in MySQL (via seed).

To pre-create or reset passwords manually:

```bash
# Get admin token
TOKEN=$(curl -s -X POST "https://keycloak.badr.co.id/realms/master/protocol/openid-connect/token" \
  -d "client_id=admin-cli&username=admin&password=keycloak&grant_type=password" \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['access_token'])")

# Reset password for a user (get UUID first)
USER_ID=$(curl -s -H "Authorization: Bearer $TOKEN" \
  "https://keycloak.badr.co.id/admin/realms/smile/users?username=arya&exact=true" \
  | python3 -c "import sys,json; print(json.load(sys.stdin)[0]['id'])")

curl -s -X PUT -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  "https://keycloak.badr.co.id/admin/realms/smile/users/$USER_ID/reset-password" \
  -d '{"type":"password","value":"Admin1234!","temporary":false}'
```

---

## Step 13 — Verify Deployment

```bash
# All pods running
KUBECONFIG=~/.kube/config.badr-dev kubectl get pods -n smile-health

# Login works
curl -s -X POST https://smile-health.badr.co.id/auth/login \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d 'username=admin&password=Admin1234!&device_type=web' | python3 -m json.tool

# Core profile
TOKEN=<access_token_from_above>
curl -s -H "Authorization: Bearer $TOKEN" https://smile-health.badr.co.id/core/account/profile
curl -s -H "Authorization: Bearer $TOKEN" https://smile-health.badr.co.id/core/account/workspaces
curl -s -H "Authorization: Bearer $TOKEN" https://smile-health.badr.co.id/core/notifications/count
```

Expected: all return HTTP 200.
