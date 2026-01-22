# Smile Health Helm Chart Installation Guide

This guide provides comprehensive step-by-step instructions for installing and configuring the Smile Health application using Helm charts.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Repository Setup](#repository-setup)
3. [Quick Start](#quick-start)
4. [Detailed Installation](#detailed-installation)
5. [Configuration](#configuration)
6. [Post-Installation](#post-installation)
7. [Upgrading](#upgrading)
8. [Uninstalling](#uninstalling)
9. [Troubleshooting](#troubleshooting)
10. [CI/CD Integration](#cicd-integration)

## Prerequisites

### Required Software

- **Kubernetes** version 1.20 or later
- **Helm** version 3.0 or later
- **kubectl** configured to connect to your Kubernetes cluster

### Cluster Requirements

- Minimum 3 worker nodes
- Each node with at least:
  - 2 CPU cores
  - 4GB RAM
  - 20GB storage
- Ingress controller installed (nginx recommended)
- Cert-manager installed (for TLS certificates)

### Verify Prerequisites

```bash
# Check Kubernetes version
kubectl version --short

# Check Helm version
helm version

# Verify cluster access
kubectl cluster-info

# Check for ingress controller
kubectl get pods -n ingress-nginx

# Check for cert-manager
kubectl get pods -n cert-manager
```

## Repository Setup

### Option 1: Using GitHub Pages (Recommended)

1. **Package the Chart:**
   ```bash
   cd c:/laragon/www/smile-health/helm
   make package
   ```

2. **Initialize GitHub Pages:**
   ```bash
   git checkout --orphan gh-pages
   mkdir charts
   cp smile-health-*.tgz charts/
   helm repo index charts/
   git add charts/
   git commit -m "Add Helm chart packages"
   git push origin gh-pages
   ```

3. **Add the Repository:**
   ```bash
   helm repo add smile-health https://your-username.github.io/smile-health/charts
   helm repo update
   ```

### Option 2: Using ChartMuseum

1. **Install ChartMuseum:**
   ```bash
   # Using Docker
   docker run --rm -it \
     -p 8080:8080 \
     -e STORAGE=local \
     -e STORAGE_LOCAL_ROOTDIR=/charts \
     -v $(pwd)/charts:/charts \
     chartmuseum/chartmuseum:latest
   ```

2. **Push the Chart:**
   ```bash
   helm plugin install https://github.com/chartmuseum/helm-push
   helm repo add chartmuseum http://localhost:8080
   helm push smile-health-*.tgz chartmuseum
   ```

### Option 3: Using Private Registry

```bash
# Login to registry
helm registry login registry.example.com

# Push the chart
helm push smile-health-*.tgz oci://registry.example.com/charts
```

### Image Repository Setup

1. **Docker Hub (Default):**
   ```bash
   docker tag smile-health/core:latest your-org/smile-health-core:v1.0.0
   docker push your-org/smile-health-core:v1.0.0
   ```

2. **GitHub Container Registry:**
   ```bash
   echo $GITHUB_TOKEN | docker login ghcr.io -u your-username --password-stdin
   docker tag smile-health/core:latest ghcr.io/your-username/smile-health-core:v1.0.0
   docker push ghcr.io/your-username/smile-health-core:v1.0.0
   ```

3. **AWS ECR:**
   ```bash
   aws ecr create-repository --repository-name smile-health/core
   docker tag smile-health/core:latest 123456789.dkr.ecr.region.amazonaws.com/smile-health/core:v1.0.0
   docker push 123456789.dkr.ecr.region.amazonaws.com/smile-health/core:v1.0.0
   ```

## Quick Start

For a quick installation with default settings (suitable for development):

### Step 1: Clone and Prepare
```bash
# Clone the repository
git clone <repository-url>
cd smile-health/helm

# Using the Makefile (Recommended)
make quick-install

# Or manually:
# Update dependencies
helm dependency update ./smile-health

# Install the chart
helm install smile-health ./smile-health
```

### Step 2: Verify Installation
```bash
# Check the installation
make pods
make services

# Watch pod status
watch kubectl get pods -l app.kubernetes.io/instance=smile-health
```

### Step 3: Access Services
```bash
# Port forward to access locally
make port-forward

# Access applications at:
# http://localhost:7500 - Web Application
# http://localhost:3000 - Core API
# http://localhost:8080 - Keycloak Admin
```

## Detailed Installation

### Step 1: Prepare the Environment

```bash
# Create a namespace for the application (recommended)
kubectl create namespace smile-health

# Set the namespace as default
kubectl config set-context --current --namespace=smile-health

# Verify cluster readiness
make dev-setup
```

### Step 2: Configure Values

Choose the appropriate values file for your environment:

```bash
# Development (default)
values=./smile-health/values.yaml

# Staging
values=./smile-health/values-staging.yaml

# Production
values=./smile-health/values-production.yaml

# Local development
make install-local  # Creates values-local.yaml automatically
```

### Step 3: Customize Configuration (Optional)

Create a custom values file:

```bash
# Copy the appropriate values file
cp ./smile-health/values-production.yaml ./smile-health/values-custom.yaml

# Edit the file with your specific configurations
nano ./smile-health/values-custom.yaml
```

**Key configurations to customize:**

1. **Image Registry and Tags:**
   ```yaml
   global:
     imageRegistry: ghcr.io/your-username
   
   backend:
     core:
       image:
         tag: "v1.2.3"
   ```

2. **Resource Limits:**
   ```yaml
   resources:
     limits:
       cpu: 1000m
       memory: 1Gi
     requests:
       cpu: 500m
       memory: 512Mi
   ```

3. **Ingress Configuration:**
   ```yaml
   ingress:
     hosts:
       - host: smile-health.yourdomain.com
         paths:
           - path: /
             pathType: Prefix
   ```

4. **Database Credentials:**
   ```yaml
   mysql:
     auth:
       rootPassword: "your-secure-root-password"
       password: "your-secure-user-password"
   ```

5. **TLS Certificates:**
   ```yaml
   ingress:
     tls:
       - secretName: smile-health-tls
         hosts:
           - smile-health.yourdomain.com
   ```

### Step 4: Install Dependencies

```bash
# Using Makefile
make deps

# Or manually
helm dependency update ./smile-health
```

### Step 5: Validate the Chart

```bash
# Lint the chart
make lint

# Render templates
make template

# Dry-run installation
make dry-run
```

### Step 6: Install the Chart

```bash
# Using Makefile with custom values
helm upgrade --install smile-health ./smile-health \
  --namespace smile-health \
  --values ./smile-health/values-custom.yaml \
  --timeout 10m

# Or using Makefile
make install VALUES_FILE=./smile-health/values-custom.yaml
```

### Step 7: Verify Installation

```bash
# Check all pods
make pods

# Check services
make services

# Check ingress
make ingress

# Check deployment status
make status

# Watch pod status
watch kubectl get pods -l app.kubernetes.io/instance=smile-health

# Check all components
kubectl get all -l app.kubernetes.io/instance=smile-health
```

## Configuration

### Environment-Specific Configurations

#### Development Environment

```yaml
# values-dev.yaml
global:
  environment: development

replicaCount: 1

autoscaling:
  enabled: false

resources:
  limits:
    cpu: 500m
    memory: 512Mi
  requests:
    cpu: 100m
    memory: 128Mi
```

#### Staging Environment

```yaml
# values-staging.yaml
global:
  environment: staging

replicaCount: 2

autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 4
  targetCPUUtilizationPercentage: 70

resources:
  limits:
    cpu: 1000m
    memory: 1Gi
  requests:
    cpu: 500m
    memory: 512Mi
```

#### Production Environment

```yaml
# values-production.yaml
global:
  environment: production

replicaCount: 3

autoscaling:
  enabled: true
  minReplicas: 3
  maxReplicas: 10
  targetCPUUtilizationPercentage: 70

resources:
  limits:
    cpu: 2000m
    memory: 2Gi
  requests:
    cpu: 1000m
    memory: 1Gi

# Enable TLS
ingress:
  tls:
    - secretName: smile-health-tls
      hosts:
        - smile-health.example.com
```

### Database Configuration

#### External Database

```yaml
# Use external MySQL
mysql:
  enabled: false

externalDatabase:
  host: mysql.example.com
  port: 3306
  database: smile_health
  username: smile_user
  password: "your-secure-password"
```

#### Internal Database

```yaml
# Use internal MySQL
mysql:
  enabled: true
  auth:
    rootPassword: "secure-root-password"
    database: smile_health
    username: smile_user
    password: "secure-user-password"
  primary:
    persistence:
      size: 20Gi
      storageClass: fast-ssd
```

### Ingress Configuration

```yaml
ingress:
  enabled: true
  className: nginx
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
    nginx.ingress.kubernetes.io/rate-limit: "100"
    nginx.ingress.kubernetes.io/rate-limit-window: "1m"
  hosts:
    - host: smile-health.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: smile-health-tls
      hosts:
        - smile-health.example.com
```

## Post-Installation

### Access the Application

Once all pods are running, you can access:

- **Main Application**: `https://<your-host>/`
- **API Documentation**: `https://<your-host>/api/docs`
- **WMS Application**: `https://<your-host>/wms/`
- **Keycloak Admin**: `https://<your-host>/auth/`

### Initialize Keycloak

```bash
# Get Keycloak admin password
kubectl get secret smile-health-keycloak -o jsonpath="{.data.adminPassword}" | base64 -d

# Port forward to access Keycloak
kubectl port-forward service/smile-health-keycloak 8080:80

# Access Keycloak at http://localhost:8080
```

### Run Database Migrations

```bash
# Access a backend pod
kubectl exec -it deployment/smile-health-core -- bash

# Run migrations
npm run migration:run
```

## Upgrading

### Prepare for Upgrade

```bash
# Check current version
helm list -n smile-health

# Backup current configuration
helm get values smile-health -n smile-health > current-values.yaml

# Review upgrade history
make history
```

### Standard Upgrade

```bash
# Update dependencies
make deps

# Upgrade with Makefile
make upgrade

# Or manually
helm upgrade smile-health ./smile-health \
  --values ./smile-health/values-custom.yaml
```

### Rolling Upgrade with Zero Downtime

```bash
# Upgrade with specific strategy
helm upgrade smile-health ./smile-health \
  --values ./smile-health/values-custom.yaml \
  --set strategy.type=RollingUpdate \
  --set strategy.rollingUpdate.maxUnavailable=1 \
  --set strategy.rollingUpdate.maxSurge=1

# Monitor the upgrade
watch kubectl rollout status deployment/smile-health-core
```

### Blue-Green Deployment

```bash
# Install new version with different name
helm install smile-health-green ./smile-health \
  --values ./smile-health/values-green.yaml

# Switch ingress to new version
kubectl patch ingress smile-health -p '{
  "spec": {
    "rules": [{
      "host": "smile-health.example.com",
      "http": {
        "paths": [{
          "path": "/",
          "pathType": "Prefix",
          "backend": {
            "service": {
              "name": "smile-health-green-web",
              "port": {
                "number": 7500
              }
            }
          }
        }]
      }
    }]
  }
}'

# Cleanup old version
helm uninstall smile-health
```

### Upgrade History and Rollback

```bash
# View upgrade history
make history

# View detailed revision
helm history smile-health -n smile-health -o yaml

# Rollback to previous version
make rollback

# Rollback to specific revision
helm rollback smile-health <revision-number> -n smile-health

# Verify rollback
make status
```

## Uninstalling

### Complete Removal

```bash
# Using Makefile
make uninstall

# Or manually
helm uninstall smile-health --namespace smile-health

# Wait for pods to terminate
kubectl wait --for=delete pod -l app.kubernetes.io/instance=smile-health -n smile-health --timeout=300s

# Remove PVCs (optional, will delete data)
kubectl delete pvc -l app.kubernetes.io/instance=smile-health -n smile-health

# Remove secrets (optional)
kubectl delete secret -l app.kubernetes.io/instance=smile-health -n smile-health

# Remove namespace
kubectl delete namespace smile-health
```

### Preserve Data

```bash
# Uninstall but keep PVCs
helm uninstall smile-health --namespace smile-health --keep-history

# List remaining PVCs
kubectl get pvc -l app.kubernetes.io/instance=smile-health -n smile-health

# Backup data before removal
kubectl exec -it deployment/smile-health-mysql -- mysqldump -u root -p --all-databases > backup.sql
```

### Selective Component Removal

```bash
# Disable specific components
helm upgrade smile-health ./smile-health \
  --set backend.immunization.enabled=false \
  --set backend.medicine.enabled=false \
  --set frontend.storybook.enabled=false

# Remove dependencies
helm upgrade smile-health ./smile-health \
  --set redis.enabled=false \
  --set rabbitmq.enabled=false
```

## Troubleshooting

### Common Issues

#### Pods Not Starting

```bash
# Check pod status and events
kubectl describe pod <pod-name>

# Check logs
kubectl logs <pod-name> --previous

# Check resource usage
kubectl top nodes
kubectl top pods
```

#### Ingress Not Working

```bash
# Check ingress controller logs
kubectl logs -n ingress-nginx deployment/ingress-nginx-controller

# Check ingress configuration
kubectl describe ingress smile-health

# Test connectivity
kubectl run test-pod --image=busybox --rm -it -- /bin/sh
# Inside pod: wget -qO- http://<service-name>
```

#### Database Connection Issues

```bash
# Test database connection
kubectl run mysql-client --image=mysql:8.0 --rm -it -- mysql -h <mysql-host> -u <username> -p

# Check database secrets
kubectl get secret smile-health-mysql -o yaml
```

#### Authentication Issues

```bash
# Check Keycloak status
kubectl logs deployment/smile-health-keycloak

# Reset admin password
kubectl patch secret smile-health-keycloak -p='{"data":{"adminPassword":"<base64-encoded-password>"}}'
```

### Debug Commands

```bash
# Port forward for local debugging
kubectl port-forward service/smile-health-core 3000:3000

# Exec into container
kubectl exec -it deployment/smile-health-core -- bash

# Check events
kubectl get events --sort-by=.metadata.creationTimestamp

# Check resource quotas
kubectl describe namespace smile-health
```

### Performance Issues

```bash
# Check resource utilization
kubectl top pods -l app.kubernetes.io/name=smile-health

# Check HPA status
kubectl get hpa

# Check node resources
kubectl describe nodes
```

## Support

For additional support:

1. Check the [main README](./README.md) for configuration options
2. Review the Helm chart documentation
3. Check Kubernetes logs and events
4. Verify all prerequisites are met
5. Ensure resource limits are appropriate for your cluster

## Best Practices

1. **Always test in a staging environment first**
2. **Use version-pinned values files for production**
3. **Regularly backup persistent data**
4. **Monitor resource usage and set appropriate limits**
5. **Use network policies in production**
6. **Enable audit logging**
7. **Regularly update dependencies**
8. **Implement proper CI/CD pipelines for deployments**
9. **Use secrets management for sensitive data**
10. **Implement health checks and readiness probes**

## CI/CD Integration

### GitHub Actions Example

```yaml
# .github/workflows/deploy.yml
name: Deploy to Kubernetes

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Helm
        uses: azure/setup-helm@v3
        
      - name: Configure kubectl
        uses: azure/k8s-set-context@v3
        with:
          method: kubeconfig
          kubeconfig: ${{ secrets.KUBE_CONFIG }}
          
      - name: Deploy to Kubernetes
        run: |
          cd helm
          make deps
          make upgrade VALUES_FILE=./smile-health/values-production.yaml
```

### GitLab CI/CD Example

```yaml
# .gitlab-ci.yml
deploy:
  stage: deploy
  image:
    name: alpine/helm:3.10.0
    entrypoint: [""]
  script:
    - cd helm
    - helm dependency update ./smile-health
    - helm upgrade --install smile-health ./smile-health
      --namespace smile-health
      --values ./smile-health/values-production.yaml
  environment:
    name: production
    url: https://smile-health.example.com
```

### Jenkins Pipeline Example

```groovy
pipeline {
  agent any
  
  stages {
    stage('Deploy') {
      steps {
        dir('helm') {
          sh 'make deps'
          sh 'make upgrade'
        }
      }
    }
  }
  
  post {
    success {
      sh 'make status'
    }
    failure {
      sh 'make history'
      sh 'make rollback'
    }
  }
}
```

### Automated Testing Pipeline

```bash
#!/bin/bash
# deploy-test.sh

set -e

echo "Running deployment tests..."

# Lint chart
make lint

# Dry-run
make dry-run

# Deploy to test namespace
helm upgrade --install smile-health-test ./smile-health \
  --namespace test \
  --create-namespace \
  --values ./smile-health/values-test.yaml

# Run tests
make test

# Check health
kubectl wait --for=condition=ready pod -l app.kubernetes.io/instance=smile-health-test -n test --timeout=300s

# Cleanup
helm uninstall smile-health-test -n test

echo "All tests passed!"
```
