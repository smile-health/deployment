# Smile Health Docker Compose Setup

Docker Compose setup for local development and testing of the Smile Health application.

## Structure

All Docker-related files are organized in the `docker/` directory:

```
deployment/
├── Makefile                    # Main management commands
├── DOCKER_SETUP.md            # This file
└── docker/                    # Docker compose setup
    ├── compose/               # Compose files
    │   ├── docker-compose.yml
    │   ├── compose-services.yml
    │   ├── compose-tools.yml
    │   ├── compose-data.yml
    │   └── compose-frontend.yml
    ├── env/                   # Environment files
    │   ├── .env.example
    │   └── *.env.example
    ├── volumes/               # Data volumes (gitignored)
    └── backups/               # Database backups (gitignored)
```

### Compose Files

- **docker-compose.yml** - Main compose file that includes all other files
- **compose-services.yml** - Backend services (auth-service, core, main, sync-service, warehouse-service, notification)
- **compose-tools.yml** - Infrastructure tools (MySQL, Redis, RabbitMQ, Keycloak, MinIO)
- **compose-data.yml** - Data processing services (Kafka, ClickHouse, RisingWave)
- **compose-frontend.yml** - Frontend web application

## Prerequisites

- Docker 20.10+
- Docker Compose 2.0+
- At least 8GB RAM available for Docker
- At least 20GB disk space

## Quick Start

### Using Makefile (Recommended)

```bash
cd deployment
make start
```

### Using Bash Script

```bash
cd deployment
chmod +x start.sh
./start.sh
```

## Manual Setup

### 1. Create Environment Files

```bash
# Copy root environment file
cp docker/env/.env.example docker/.env

# Copy service environment files
cp docker/env/auth-service.env.example docker/env/auth-service.env
cp docker/env/core.env.example docker/env/core.env
cp docker/env/main.env.example docker/env/main.env
cp docker/env/sync-service.env.example docker/env/sync-service.env
cp docker/env/warehouse-service.env.example docker/env/warehouse-service.env
cp docker/env/notification.env.example docker/env/notification.env
cp docker/env/frontend-web.env.example docker/env/frontend-web.env
```

Edit each `.env` file with your configuration.

### 2. Create Docker Network

```bash
docker network create smile-network
```

### 3. Start Services

```bash
# Navigate to docker/compose directory
cd docker/compose

# Start infrastructure first
docker compose -f compose-tools.yml -f compose-data.yml up -d

# Wait for infrastructure to be healthy (30-60 seconds)
docker compose -f compose-tools.yml -f compose-data.yml ps

# Start backend services
docker compose -f compose-services.yml up -d

# Start frontend
docker compose -f compose-frontend.yml up -d
```

## Service Endpoints

### Backend Services

- **Core**: http://localhost:4000
- **Auth Service**: http://localhost:4003
- **Main**: http://localhost:4004
- **Warehouse**: http://localhost:4008

### Frontend

- **Web Application**: http://localhost:4001

### Infrastructure Tools

- **MySQL**: localhost:4306
  - User: `smileuser` (default)
  - Password: `smilepass` (default)
  - Database: `smile_health` (default)

- **Redis**: localhost:4379

- **RabbitMQ**: localhost:4672
- **RabbitMQ Management**: http://localhost:4673
  - Username: `admin` (default)
  - Password: `admin` (default)

- **Keycloak Admin Console**: http://localhost:4080
  - Username: `admin` (default)
  - Password: `admin` (default)

- **MinIO API**: http://localhost:4900
- **MinIO Console**: http://localhost:4901
  - Username: `minioadmin` (default)
  - Password: `minioadmin` (default)

### Data Services

- **Zookeeper**: localhost:4181
- **Kafka**: localhost:4092 (internal), localhost:4093 (external)
- **ClickHouse HTTP**: http://localhost:4123
- **RisingWave**: localhost:4566
- **RisingWave Dashboard**: http://localhost:4691

## Management Commands

### Using Makefile (Recommended)

```bash
# Show all available commands
make help

# Start all services
make start

# Stop all services
make stop

# Restart all services
make restart

# View logs (all services)
make logs

# View logs (specific service)
make logs SERVICE=auth-service

# Restart a specific service
make restart-service SERVICE=auth-service

# Check service status
make ps

# Show service endpoints
make info
```

### Using Bash Scripts

```bash
# Start all services
./start.sh

# Stop all services
./stop.sh

# View logs (all services)
./logs.sh

# View logs (specific service)
./logs.sh auth-service

# Restart a service
./restart.sh auth-service
```

## Makefile Commands Reference

The Makefile provides convenient commands for managing the Docker Compose setup:

### Lifecycle Commands
- `make start` - Initialize and start all services
- `make stop` - Stop all services
- `make restart` - Restart all services
- `make down` - Stop and remove containers
- `make clean` - Clean up containers and networks
- `make clean-all` - Clean everything including volumes

### Selective Start/Stop
- `make start-tools` - Start only infrastructure tools
- `make start-data` - Start only data services
- `make start-services` - Start only backend services
- `make start-frontend` - Start only frontend
- `make stop-tools`, `make stop-data`, `make stop-services`, `make stop-frontend`

### Monitoring
- `make ps` - Show running containers
- `make logs` - Show all logs
- `make logs SERVICE=<name>` - Follow logs for specific service
- `make logs-tools`, `make logs-data`, `make logs-services`, `make logs-frontend`
- `make health` - Check health status
- `make info` - Show service endpoints and credentials (displays all ports)

### Development
- `make build` - Build all service images
- `make build-service SERVICE=<name>` - Build specific service
- `make shell SERVICE=<name>` - Open shell in service container
- `make mysql` - Connect to MySQL CLI
- `make redis-cli` - Connect to Redis CLI

### Database Operations
- `make backup-db` - Backup MySQL database
- `make restore-db FILE=<path>` - Restore MySQL database

### Utilities
- `make validate` - Validate docker-compose files
- `make update` - Pull images, rebuild, and restart
- `make help` - Show all available commands

## Volume Management

All data is stored in the `docker/volumes/` directory:

```
docker/volumes/
├── mysql/              # MySQL data
├── redis/              # Redis data
├── rabbitmq/           # RabbitMQ data
├── rabbitmq-logs/      # RabbitMQ logs
├── keycloak-postgres/  # Keycloak database
├── minio/              # MinIO object storage
├── zookeeper/          # Zookeeper data
├── zookeeper-logs/     # Zookeeper logs
├── kafka/              # Kafka data
├── clickhouse/         # ClickHouse data
├── clickhouse-logs/    # ClickHouse logs
└── risingwave/         # RisingWave data
```

### Clean Up Volumes

```bash
# Using Makefile (with confirmation prompt)
make clean-all

# Or manually
cd docker/compose
docker compose -f compose-services.yml -f compose-tools.yml -f compose-data.yml -f compose-frontend.yml down
cd ..
rm -rf volumes/
```

## Troubleshooting

### Services Not Starting

Check if ports are already in use:

```bash
# Windows
netstat -ano | findstr ":3000"
netstat -ano | findstr ":3306"

# Linux/Mac
lsof -i :3000
lsof -i :3306
```

### Check Service Health

```bash
make health
# or
make ps
```

### View Service Logs

```bash
# All logs
make logs

# Specific service
make logs SERVICE=auth-service
```

### Reset Everything

```bash
# Using Makefile (from deployment directory)
make clean-all

# Or manually
cd docker/compose
docker compose -f compose-services.yml -f compose-tools.yml -f compose-data.yml -f compose-frontend.yml down -v
cd ..
rm -rf volumes/
docker network rm smile-network

# Start fresh (from deployment directory)
cd ../..
make start
```

### Database Connection Issues

If services can't connect to MySQL:

1. Check MySQL is healthy: `make health` or `make ps`
2. Check MySQL logs: `make logs SERVICE=mysql`
3. Verify credentials in service `.env` files match `.env` root file
4. Ensure services are on the same network: `docker network inspect smile-network`

### Memory Issues

If services are crashing due to memory:

1. Increase Docker memory limit (Docker Desktop settings)
2. Start services in stages:
   ```bash
   # Start only essential tools
   docker compose -f compose-tools.yml up -d mysql redis rabbitmq
   
   # Then start core services
   docker compose -f compose-services.yml up -d core auth-service main
   ```

## Development Tips

### Rebuild a Service

```bash
make build-service SERVICE=auth-service
make restart-service SERVICE=auth-service
```

### Access MySQL

```bash
make mysql
```

### Access Redis CLI

```bash
make redis-cli
```

### Access Container Shell

```bash
make shell SERVICE=auth-service
```

### Backup and Restore Database

```bash
# Backup
make backup-db

# Restore
make restore-db FILE=docker/backups/backup_20260127_151000.sql
```

## Production Considerations

This setup is for **development and testing only**. For production:

- Use proper secrets management
- Configure TLS/SSL certificates
- Use external managed databases
- Implement proper backup strategies
- Configure resource limits
- Use production-grade images
- Implement monitoring and logging
- Configure network policies
- Use container orchestration (Kubernetes)
