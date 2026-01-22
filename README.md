# Smile Health Helm Chart

This Helm chart deploys the Smile Health application, including all backend services, frontend applications, and necessary dependencies.

## Architecture

The chart deploys:
- **Backend Services**: Core, Immunization, Medicine, Auth, Main, Sync, Warehouse, Main API, Warehouse API, Notification
- **Frontend Applications**: Web, Storybook, WMS
- **Infrastructure**: MySQL, Redis, RabbitMQ, Keycloak (with MySQL backend)

## Prerequisites

- Kubernetes 1.20+
- Helm 3.0+
- Ingress controller (nginx recommended)
- Cert-manager (for TLS certificates)

## Installation

### Add Dependencies

```bash
helm dependency update ./smile-health
```

### Install the Chart

```bash
# Install with default values (development)
helm install smile-health ./smile-health

# Install with staging values
helm install smile-health ./smile-health -f ./smile-health/values-staging.yaml

# Install with production values
helm install smile-health ./smile-health -f ./smile-health/values-production.yaml
```

### Upgrade the Chart

```bash
helm upgrade smile-health ./smile-health -f ./smile-health/values-production.yaml
```

### Uninstall the Chart

```bash
helm uninstall smile-health
```

## Configuration

### Global Settings

| Parameter | Description | Default |
|-----------|-------------|---------|
| `global.imageRegistry` | Global Docker image registry | `""` |
| `global.imagePullSecrets` | Global image pull secrets | `[]` |
| `global.storageClass` | Global storage class | `""` |

### Common Settings

| Parameter | Description | Default |
|-----------|-------------|---------|
| `replicaCount` | Number of replicas | `1` |
| `image.pullPolicy` | Image pull policy | `IfNotPresent` |
| `resources` | Resource limits and requests | `{}` |
| `autoscaling.enabled` | Enable horizontal pod autoscaling | `false` |

### Backend Services

Each backend service can be configured with:

| Parameter | Description | Default |
|-----------|-------------|---------|
| `backend.{service}.enabled` | Enable/disable service | `true` |
| `backend.{service}.image.repository` | Docker image repository | `smile-health/{service}` |
| `backend.{service}.image.tag` | Docker image tag | `latest` |
| `backend.{service}.service.port` | Service port | Varies |
| `backend.{service}.resources` | Resource limits/requests | `{}` |
| `backend.{service}.env` | Environment variables | `[]` |
| `backend.{service}.envFrom` | Environment variable sources | `[]` |

### Frontend Services

Each frontend service can be configured with:

| Parameter | Description | Default |
|-----------|-------------|---------|
| `frontend.{service}.enabled` | Enable/disable service | `true` |
| `frontend.{service}.image.repository` | Docker image repository | `smile-health/{service}` |
| `frontend.{service}.image.tag` | Docker image tag | `latest` |
| `frontend.{service}.service.port` | Service port | Varies |
| `frontend.{service}.resources` | Resource limits/requests | `{}` |
| `frontend.{service}.env` | Environment variables | `[]` |
| `frontend.{service}.envFrom` | Environment variable sources | `[]` |

### Ingress Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `ingress.enabled` | Enable ingress | `true` |
| `ingress.className` | Ingress class name | `nginx` |
| `ingress.annotations` | Ingress annotations | `{}` |
| `ingress.hosts` | Host configurations | `[]` |
| `ingress.tls` | TLS configuration | `[]` |

### Dependencies

#### MySQL

| Parameter | Description | Default |
|-----------|-------------|---------|
| `mysql.enabled` | Enable MySQL | `true` |
| `mysql.auth.rootPassword` | MySQL root password | `mysql123` |
| `mysql.auth.database` | Default database | `smile_health` |
| `mysql.auth.username` | Database user | `smile_user` |
| `mysql.auth.password` | Database password | `smile123` |
| `mysql.primary.persistence.size` | Storage size | `8Gi` |

#### Redis

| Parameter | Description | Default |
|-----------|-------------|---------|
| `redis.enabled` | Enable Redis | `true` |
| `redis.auth.enabled` | Enable Redis auth | `false` |
| `redis.master.persistence.size` | Storage size | `4Gi` |

#### RabbitMQ

| Parameter | Description | Default |
|-----------|-------------|---------|
| `rabbitmq.enabled` | Enable RabbitMQ | `true` |
| `rabbitmq.auth.username` | RabbitMQ username | `smile_user` |
| `rabbitmq.auth.password` | RabbitMQ password | `smile123` |
| `rabbitmq.persistence.size` | Storage size | `4Gi` |

#### Keycloak

| Parameter | Description | Default |
|-----------|-------------|---------|
| `keycloak.enabled` | Enable Keycloak | `true` |
| `keycloak.auth.adminUser` | Admin username | `admin` |
| `keycloak.auth.adminPassword` | Admin password | `admin123` |
| `keycloak.database.type` | Database type | `mysql` |
| `keycloak.database.hostname` | Database host | `smile-health-mysql` |
| `keycloak.database.database` | Database name | `keycloak` |
| `keycloak.database.user` | Database user | `smile_user` |
| `keycloak.database.password` | Database password | `smile123` |

## Service Endpoints

After deployment, services will be available at:

- **Main Application**: `http://<ingress-host>/`
- **API Endpoints**: `http://<ingress-host>/api/`
- **WMS Application**: `http://<ingress-host>/wms/`
- **Storybook**: `http://<ingress-host>/storybook/` (if enabled)
- **Keycloak Admin Console**: `http://<ingress-host>/auth/`

### Internal Service Names

Services are accessible within the cluster using:

- Backend services: `smile-health-{service-name}`
- Frontend services: `smile-health-{service-name}`
- MySQL: `smile-health-mysql`
- Redis: `smile-health-redis-master`
- RabbitMQ: `smile-health-rabbitmq`
- Keycloak: `smile-health-keycloak`

## Development

### Local Development with Minikube

```bash
# Start Minikube
minikube start

# Enable ingress addon
minikube addons enable ingress

# Install the chart
helm install smile-health ./smile-health

# Get the URL
minikube service smile-health-web --url
```

### Building Docker Images

```bash
# Build backend images
cd backend
docker build -t smile-health/core:latest ./apps/core
docker build -t smile-health/platform:latest ./apps/platform
# ... build other services

# Build frontend images
cd ../frontend
docker build -t smile-health/web:latest -f apps/web/Dockerfile .
docker build -t smile-health/wms:latest -f apps/wms/Dockerfile .
# ... build other services
```

## Monitoring

The chart includes health checks for all services:

- **Liveness Probe**: Checks if the service is running
- **Readiness Probe**: Checks if the service is ready to accept traffic

Health check endpoints:
- Backend services: `/health`
- Frontend services: `/`

## Troubleshooting

### Check Pod Status

```bash
kubectl get pods -l app.kubernetes.io/name=smile-health
```

### Check Service Status

```bash
kubectl get services -l app.kubernetes.io/name=smile-health
```

### Check Ingress Status

```bash
kubectl get ingress smile-health
```

### View Logs

```bash
# View all logs
kubectl logs -l app.kubernetes.io/name=smile-health

# View specific service logs
kubectl logs -l app.kubernetes.io/component=core
```

### Port Forwarding

```bash
# Forward a service locally
kubectl port-forward service/smile-health-core 3000:3000
```

## Security Considerations

- All containers run as non-root user
- All capabilities are dropped
- Security contexts are configured
- Use secrets for sensitive data
- Enable network policies in production
- Use TLS certificates in production
- Configure external database connections securely
- Use external authentication providers

## Contributing

When modifying the chart:

1. Test changes in a development environment first
2. Update documentation for any new parameters
3. Follow Helm best practices
4. Validate the chart: `helm lint ./smile-health`
5. Test template rendering: `helm template ./smile-health`

## License

This chart is licensed under the same license as the Smile Health project.