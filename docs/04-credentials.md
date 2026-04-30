# Credentials — smile-health (Dev)

## Application Login

Both users are Super Admin (role=1), entity PUSKESMAS BOGOR SELATAN (id=37),
assigned to all 14 active workspaces/programs.

| Username | Password | Email | Keycloak UUID |
|----------|----------|-------|---------------|
| `arya` | `Admin1234!` | arya@smile.co.id | `451e1122-acba-4000-a07a-141e756df8bb` |
| `admin` | `Admin1234!` | admin@smile.co.id | `93b9f3dc-b704-4fcb-9a2d-f5309efafa46` |

Login endpoint:

```bash
curl -X POST https://smile-health.badr.co.id/auth/login \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d 'username=admin&password=Admin1234!&device_type=web'
```

---

## Database Access

| Service | Host | Database | User | Password |
|---------|------|----------|------|----------|
| MySQL | `mysql.smile-health.svc.cluster.local:3306` | `dev_smile_health` | `devel` | `niatikhla5` |
| MySQL | `mysql.smile-health.svc.cluster.local:3306` | `dev_smile_health_mapping` | `devel` | `niatikhla5` |
| MySQL | `mysql.smile-health.svc.cluster.local:3306` | `dev_smile_health_notification` | `devel` | `niatikhla5` |
| MySQL root | `mysql.smile-health.svc.cluster.local:3306` | — | `root` | `niatikhla5` |
| Redis | `redis-master.smile-health.svc.cluster.local:6379` | — | — | — |
| RabbitMQ | `rabbitmq.smile-health.svc.cluster.local:5672` | — | `devel` | `niatikhla5` |

Connect to MySQL from kubectl:

```bash
KUBECONFIG=~/.kube/config.badr-dev kubectl exec -it -n smile-health statefulset/mysql -- \
  mysql -u devel -pniatikhla5 dev_smile_health
```

---

## Infrastructure Access

| Host | Purpose | SSH |
|------|---------|-----|
| 10.10.0.3 | Nginx reverse proxy | `sshpass -p "niatikhla5" ssh -p 60322 devel@10.10.0.3` |
| 10.10.0.10 | Kubernetes node (kube1) | `ssh devel@10.10.0.10` |
| 10.10.0.11 | Kubernetes node (kube2, PV storage) | `ssh devel@10.10.0.11` |

---

## Keycloak

| Item | Value |
|------|-------|
| URL | https://keycloak.badr.co.id |
| Admin user | `admin` |
| Admin password | `keycloak` |
| Realm | `smile` |
| Client ID | `smile` |

Get admin token:

```bash
TOKEN=$(curl -s -X POST "https://keycloak.badr.co.id/realms/master/protocol/openid-connect/token" \
  -d "client_id=admin-cli&username=admin&password=keycloak&grant_type=password" \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['access_token'])")
```

---

## Service Endpoints

| Service | External URL |
|---------|-------------|
| Frontend | https://smile-health.badr.co.id/ |
| Auth | https://smile-health.badr.co.id/auth/ |
| Core | https://smile-health.badr.co.id/core/ |
| Main | https://smile-health.badr.co.id/main/ |
| Account | https://smile-health.badr.co.id/account/ |
| Warehouse | https://smile-health.badr.co.id/warehouse-report/ |
| Sync | https://smile-health.badr.co.id/sync/ |
| Auth Swagger | https://smile-health.badr.co.id/auth/ui |
| Core Swagger | https://smile-health.badr.co.id/core/ui |
