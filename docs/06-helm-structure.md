# Helm Structure — smile-health

## Overview

All Kubernetes deployment files live in the `helm/` directory of this repo.

```
helm/
├── smile-app-0.1.0-patched.tgz          # Shared helm chart (patched)
├── smile-health-deploy.sh               # Deploy script for all services
├── backend/
│   ├── smile-health-auth-service-dev-onprem.yaml
│   ├── smile-health-core-dev-onprem.yaml
│   ├── smile-health-main-dev-onprem.yaml
│   ├── smile-health-warehouse-service-dev-onprem.yaml
│   ├── smile-health-sync-service-dev-onprem.yaml
│   ├── smile-health-notification-dev-onprem.yaml
│   └── virtualservice/
│       └── vs-smile-health-dev-onprem.yml
└── frontend/
    └── smile-health-frontend-dev.yaml
```

---

## The Helm Chart

`smile-app-0.1.0-patched.tgz` is a shared chart used by all smile-* services.
It is sourced from chartmuseum but patched to add `envFrom` support, which is missing
from the original.

**What the patch adds** to `templates/deployment.yaml`:

```yaml
{{- with .Values.app.envFrom }}
envFrom:
  {{- toYaml . | nindent 12 }}
{{- end }}
```

Without this patch, Kubernetes secrets referenced in `app.envFrom` in the values file
are ignored and pods start without any env vars injected.

---

## Values File Structure

Each service has one values file. The key fields:

```yaml
replicaCount: 1

app:
  name: smile-health-core             # Kubernetes resource name
  environment: dev
  group: smile
  image:
    registry: ghcr.io
    repository: smile-health/backend/core
    pullPolicy: Always
    tag: "main"
    command: |-
      printenv > .env && bun run src/server.ts
  ports:
    - name: http-port
      containerPort: 3000
      protocol: TCP
  envFrom:
    - secretRef:
        name: common-secret           # Shared env vars
    - secretRef:
        name: core-secret             # Service-specific env vars

service:
  type: ClusterIP
  ports:
    - name: http
      protocol: TCP
      targetPort: http-port
      port: 80

resources: {}
livenessProbe: null
readinessProbe: null

autoscaling:
  enabled: true
  minReplicas: 1
  maxReplicas: 1
  targetCPUUtilizationPercentage: 75
```

**Why `command` uses `|-`**: YAML block literal syntax avoids escape sequence parsing errors.
Double-quoted strings interpret `\n`, `\t`, etc., which breaks commands containing backslashes.

**Why `printenv > .env`**: The application uses dotenvx, which reads from `.env`.
Since secrets are injected as environment variables by Kubernetes (via `envFrom`), dumping them
to `.env` with `printenv` bridges this gap without needing a secrets-store CSI driver.

---

## Deploy Script

`helm/smile-health-deploy.sh` deploys any or all services:

```bash
# Deploy everything
./smile-health-deploy.sh all

# Deploy a single service
./smile-health-deploy.sh core
./smile-health-deploy.sh frontend
./smile-health-deploy.sh vs        # applies VirtualService only
```

The script sets `KUBECONFIG` from the environment (defaults to `~/.kube/config.badr-dev`)
and uses `helm upgrade --install` so it is idempotent and safe to re-run.

---

## VirtualService

`helm/backend/virtualservice/vs-smile-health-dev-onprem.yml` defines Istio routing for
`smile-health.badr.co.id`.

Route table:

| Path prefix | Destination service | Port |
|-------------|---------------------|------|
| `/auth/` | `smile-health-auth-service` | 80 |
| `/core/` | `smile-health-core` | 80 |
| `/main/`, `/account/` | `smile-health-main` | 80 |
| `/warehouse-report/` | `smile-health-warehouse-service` | 80 |
| `/sync/` | `smile-health-sync-service` | 80 |
| `/notification/` | `smile-health-notification` | 80 |
| `/` (catch-all) | `smile-health-frontend` | 80 |

The VirtualService is in namespace `smile-health` and attaches to gateway `istio-system/badr-gateway`.

Apply:

```bash
KUBECONFIG=~/.kube/config.badr-dev kubectl apply -f helm/backend/virtualservice/vs-smile-health-dev-onprem.yml
```

---

## CI/CD Integration

Images are built and pushed to GHCR by GitHub Actions in the respective repos:

| Repo | Workflow | Image |
|------|----------|-------|
| `smile-health/backend` | `.github/workflows/docker-build.yml` | `ghcr.io/smile-health/backend/*` |
| `smile-health/frontend` | `.github/workflows/docker-build.yml` | `ghcr.io/smile-health/frontend/web` |

On push to `main`, images are tagged with both `:main` (branch) and `:<git-sha>`.
Values files use `tag: "main"` so deployments pick up the latest build automatically on pod restart.

To trigger a rolling update after a new image is pushed:

```bash
KUBECONFIG=~/.kube/config.badr-dev kubectl rollout restart deployment/smile-health-core -n smile-health
```
