# Seeded Credentials — smile-health (Dev)

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
| MySQL (in-cluster) | `mysql.smile-health.svc.cluster.local:3306` | `dev_smile_health` | `devel` | `niatikhla5` |
| MySQL (in-cluster) | `mysql.smile-health.svc.cluster.local:3306` | `dev_smile_health_mapping` | `devel` | `niatikhla5` |
| MySQL (in-cluster) | `mysql.smile-health.svc.cluster.local:3306` | `dev_smile_health_notification` | `devel` | `niatikhla5` |
| Redis | `redis-master.smile-health.svc.cluster.local:6379` | — | — | — |
| RabbitMQ | `rabbitmq.smile-health.svc.cluster.local:5672` | — | `devel` | `niatikhla5` |

---

## Keycloak

| Item | Value |
|------|-------|
| URL | https://keycloak.badr.co.id |
| Admin user | `admin` |
| Admin password | `keycloak` |
| Realm | `smile` |
| Client ID | `smile` |

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
| Auth Swagger UI | https://smile-health.badr.co.id/auth/ui |
| Core Swagger UI | https://smile-health.badr.co.id/core/ui |

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

---

## Active Programs (Workspaces)

All seeded users and the entity above are assigned to these 14 programs:

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
