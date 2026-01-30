# Docker Compose Quick Start

Step-by-step guide to run the Smile Health Docker Compose setup.

## Prerequisites

- Docker 24.0+
- Docker Compose (included with Docker Desktop)
- 8GB+ RAM available
- Ports 4000-4901 available

## Quick Start (Automated)

```bash
# From deployment/docker/compose directory
chmod +x setup.sh
./setup.sh
```

This script will:
1. Create environment files from examples
2. Create volume directories
3. Create Docker network
4. Start all services

## Step-by-Step Manual Setup

### Step 1: Create Environment Files

Copy example environment files to actual files:

```bash
# From deployment/docker/compose directory
cd ..

# Copy root environment file
cp env/.env.example .env

# Copy service environment files
cp env/auth-service.env.example env/auth-service.env
cp env/core.env.example env/core.env
cp env/main.env.example env/main.env
cp env/sync-service.env.example env/sync-service.env
cp env/warehouse-service.env.example env/warehouse-service.env
cp env/notification.env.example env/notification.env
cp env/frontend-web.env.example env/frontend-web.env
```

Edit `.env` and service env files with your configuration if needed.

### Step 2: Create Volume Directories

```bash
# From deployment/docker directory
mkdir -p volumes/{mysql,redis,rabbitmq,rabbitmq-logs,keycloak-postgres,minio,zookeeper,zookeeper-logs,kafka,clickhouse,clickhouse-logs,risingwave}
```

### Step 3: Create Docker Network

```bash
docker network create smile-network
```

### Step 4: Start Infrastructure Services

Start database and message queue services first:

```bash
# From deployment/docker/compose directory
docker compose -f compose-tools.yml -f compose-data.yml up -d
```

Wait for services to be healthy (30-60 seconds):

```bash
docker compose -f compose-tools.yml -f compose-data.yml ps
```

All services should show `healthy` status.

### Step 5: Start Backend Services

```bash
docker compose -f compose-services.yml up -d
```

Check status:

```bash
docker compose -f compose-services.yml ps
```

### Step 6: Start Frontend

```bash
docker compose -f compose-frontend.yml up -d
```

Check status:

```bash
docker compose -f compose-frontend.yml ps
```

## Verify Everything is Running

```bash
# Check all services
docker compose ps

# View logs
docker compose logs -f

# Check specific service
docker compose logs -f auth-service
```

## Service Endpoints

Once all services are running:

### Backend APIs
- **Core**: http://localhost:4000
- **Auth Service**: http://localhost:4003
- **Main**: http://localhost:4004
- **Warehouse**: http://localhost:4008

### Frontend
- **Web Application**: http://localhost:4001

### Infrastructure Tools
- **MySQL**: localhost:4306 (user: `smileuser`, password: `smilepass`)
- **Redis**: localhost:4379
- **RabbitMQ**: localhost:4672 (AMQP)
- **RabbitMQ Management**: http://localhost:4673 (admin/admin)
- **Keycloak**: http://localhost:4080 (admin/admin)
- **MinIO API**: http://localhost:4900
- **MinIO Console**: http://localhost:4901 (minioadmin/minioadmin)

### Data Services
- **Zookeeper**: localhost:4181
- **Kafka**: localhost:4093 (external)
- **ClickHouse**: http://localhost:4123
- **RisingWave**: localhost:4566
- **RisingWave Dashboard**: http://localhost:4691

## Common Commands

```bash
# Stop all services
docker compose down

# Stop and remove volumes
docker compose down -v

# View logs for all services
docker compose logs -f

# View logs for specific service
docker compose logs -f auth-service

# Restart a service
docker compose restart auth-service

# Execute command in container
docker compose exec auth-service bash

# View service status
docker compose ps
```

## Troubleshooting

### Services won't start
- Check if ports are already in use: `netstat -an | grep LISTEN`
- Check Docker logs: `docker compose logs`
- Ensure Docker has enough resources

### Database connection errors
- Wait for MySQL to be healthy: `docker compose ps mysql`
- Check MySQL logs: `docker compose logs mysql`
- Verify credentials in `.env` files

### Out of disk space
- Clean up volumes: `docker compose down -v`
- Remove unused Docker images: `docker image prune`

### Port conflicts
- Change ports in compose files if needed
- Or stop services using those ports

## Next Steps

1. Configure environment variables in `.env` files
2. Access the frontend at http://localhost:4001
3. Check service health and logs
4. Develop and test your application

See `../DOCKER_SETUP.md` for more detailed documentation.
