# Smile Health Docker Compose Makefile

.DEFAULT_GOAL := help

# Directories
DOCKER_DIR := docker
COMPOSE_DIR := $(DOCKER_DIR)/compose
ENV_DIR := $(DOCKER_DIR)/env
VOLUMES_DIR := $(DOCKER_DIR)/volumes

# Compose files
COMPOSE_TOOLS := $(COMPOSE_DIR)/compose-tools.yml
COMPOSE_DATA := $(COMPOSE_DIR)/compose-data.yml
COMPOSE_SERVICES := $(COMPOSE_DIR)/compose-services.yml
COMPOSE_FRONTEND := $(COMPOSE_DIR)/compose-frontend.yml
COMPOSE_ALL := $(COMPOSE_TOOLS) $(COMPOSE_DATA) $(COMPOSE_SERVICES) $(COMPOSE_FRONTEND)

# Docker compose command
DC := docker compose
DC_FILES := -f $(COMPOSE_TOOLS) -f $(COMPOSE_DATA) -f $(COMPOSE_SERVICES) -f $(COMPOSE_FRONTEND)

.PHONY: help
help: ## Display this help message
	@echo ""
	@echo "Smile Health Docker Compose Commands"
	@echo "====================================="
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n\nTargets:\n"} /^[a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2 }' $(MAKEFILE_LIST)
	@echo ""

.PHONY: init
init: ## Initialize environment files and directories
	@echo "Initializing environment..."
	@cd $(DOCKER_DIR) && if [ ! -f .env ]; then \
		echo "Creating .env file..."; \
		cp env/.env.example .env; \
	fi
	@mkdir -p $(ENV_DIR)
	@for file in $(ENV_DIR)/*.env.example; do \
		if [ -f "$$file" ]; then \
			envfile=$${file%.example}; \
			if [ ! -f "$$envfile" ]; then \
				echo "Creating $$(basename $$envfile)..."; \
				cp "$$file" "$$envfile"; \
			fi; \
		fi; \
	done
	@echo "Creating volume directories..."
	@mkdir -p $(VOLUMES_DIR)/{mysql,redis,rabbitmq,rabbitmq-logs,keycloak-postgres,minio,zookeeper,zookeeper-logs,kafka,clickhouse,clickhouse-logs,risingwave}
	@echo "Creating Docker network..."
	@docker network create smile-network 2>/dev/null || echo "Network already exists"
	@echo "Initialization complete!"

.PHONY: start
start: init ## Start all services
	@echo "Starting infrastructure (tools and data)..."
	@$(DC) -f $(COMPOSE_TOOLS) -f $(COMPOSE_DATA) up -d
	@echo "Waiting for infrastructure to be healthy..."
	@sleep 10
	@echo "Starting backend services..."
	@$(DC) -f $(COMPOSE_SERVICES) up -d
	@echo "Starting frontend..."
	@$(DC) -f $(COMPOSE_FRONTEND) up -d
	@echo ""
	@echo "All services started!"
	@$(MAKE) info

.PHONY: stop
stop: ## Stop all services
	@echo "Stopping all services..."
	@$(DC) $(DC_FILES) down
	@echo "All services stopped"

.PHONY: restart
restart: stop start ## Restart all services

.PHONY: start-tools
start-tools: init ## Start only infrastructure tools
	@echo "Starting tools (MySQL, Redis, RabbitMQ, Keycloak, MinIO)..."
	@$(DC) -f $(COMPOSE_TOOLS) up -d

.PHONY: start-data
start-data: init ## Start only data services
	@echo "Starting data services (Kafka, ClickHouse, RisingWave)..."
	@$(DC) -f $(COMPOSE_DATA) up -d

.PHONY: start-services
start-services: ## Start only backend services
	@echo "Starting backend services..."
	@$(DC) -f $(COMPOSE_SERVICES) up -d

.PHONY: start-frontend
start-frontend: ## Start only frontend
	@echo "Starting frontend..."
	@$(DC) -f $(COMPOSE_FRONTEND) up -d

.PHONY: stop-tools
stop-tools: ## Stop infrastructure tools
	@$(DC) -f $(COMPOSE_TOOLS) down

.PHONY: stop-data
stop-data: ## Stop data services
	@$(DC) -f $(COMPOSE_DATA) down

.PHONY: stop-services
stop-services: ## Stop backend services
	@$(DC) -f $(COMPOSE_SERVICES) down

.PHONY: stop-frontend
stop-frontend: ## Stop frontend
	@$(DC) -f $(COMPOSE_FRONTEND) down

.PHONY: ps
ps: ## Show running containers
	@$(DC) $(DC_FILES) ps

.PHONY: logs
logs: ## Show logs for all services (usage: make logs SERVICE=auth-service)
	@if [ -z "$(SERVICE)" ]; then \
		$(DC) $(DC_FILES) logs --tail=50; \
	else \
		$(DC) $(DC_FILES) logs -f $(SERVICE); \
	fi

.PHONY: logs-tools
logs-tools: ## Show logs for infrastructure tools
	@$(DC) -f $(COMPOSE_TOOLS) logs --tail=50

.PHONY: logs-data
logs-data: ## Show logs for data services
	@$(DC) -f $(COMPOSE_DATA) logs --tail=50

.PHONY: logs-services
logs-services: ## Show logs for backend services
	@$(DC) -f $(COMPOSE_SERVICES) logs --tail=50

.PHONY: logs-frontend
logs-frontend: ## Show logs for frontend
	@$(DC) -f $(COMPOSE_FRONTEND) logs --tail=50

.PHONY: restart-service
restart-service: ## Restart a specific service (usage: make restart-service SERVICE=auth-service)
	@if [ -z "$(SERVICE)" ]; then \
		echo "Usage: make restart-service SERVICE=<service-name>"; \
		exit 1; \
	fi
	@echo "Restarting $(SERVICE)..."
	@$(DC) $(DC_FILES) restart $(SERVICE)

.PHONY: build
build: ## Build all service images
	@echo "Building all services..."
	@$(DC) -f $(COMPOSE_SERVICES) -f $(COMPOSE_FRONTEND) build

.PHONY: build-service
build-service: ## Build a specific service (usage: make build-service SERVICE=auth-service)
	@if [ -z "$(SERVICE)" ]; then \
		echo "Usage: make build-service SERVICE=<service-name>"; \
		exit 1; \
	fi
	@echo "Building $(SERVICE)..."
	@$(DC) $(DC_FILES) build $(SERVICE)

.PHONY: pull
pull: ## Pull all images
	@echo "Pulling all images..."
	@$(DC) $(DC_FILES) pull

.PHONY: down
down: ## Stop and remove all containers, networks
	@echo "Stopping and removing all containers..."
	@$(DC) $(DC_FILES) down
	@echo "Done"

.PHONY: down-volumes
down-volumes: ## Stop and remove all containers, networks, and volumes
	@echo "WARNING: This will remove all data volumes!"
	@read -p "Are you sure? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		$(DC) $(DC_FILES) down -v; \
		rm -rf volumes/; \
		echo "All containers, networks, and volumes removed"; \
	else \
		echo "Cancelled"; \
	fi

.PHONY: clean
clean: down ## Clean up containers and networks
	@echo "Cleaning up..."
	@docker network rm smile-network 2>/dev/null || true
	@echo "Cleanup complete"

.PHONY: clean-all
clean-all: down-volumes clean ## Clean everything including volumes

.PHONY: info
info: ## Show service endpoints and credentials
	@echo ""
	@echo "=== Smile Health Services ==="
	@echo ""
	@echo "Backend Services:"
	@echo "  - Core:            http://localhost:4000"
	@echo "  - Auth Service:    http://localhost:4003"
	@echo "  - Main:            http://localhost:4004"
	@echo "  - Warehouse:       http://localhost:4008"
	@echo ""
	@echo "Frontend:"
	@echo "  - Web App:         http://localhost:4001"
	@echo ""
	@echo "Infrastructure Tools:"
	@echo "  - MySQL:           localhost:4306 (user: smileuser)"
	@echo "  - Redis:           localhost:4379"
	@echo "  - RabbitMQ:        localhost:4672"
	@echo "  - RabbitMQ Mgmt:   http://localhost:4673 (admin/admin)"
	@echo "  - Keycloak:        http://localhost:4080 (admin/admin)"
	@echo "  - MinIO API:       http://localhost:4900"
	@echo "  - MinIO Console:   http://localhost:4901 (minioadmin/minioadmin)"
	@echo ""
	@echo "Data Services:"
	@echo "  - Zookeeper:       localhost:4181"
	@echo "  - Kafka:           localhost:4093 (external)"
	@echo "  - ClickHouse:      http://localhost:4123"
	@echo "  - RisingWave:      localhost:4566"
	@echo "  - RisingWave UI:   http://localhost:4691"
	@echo ""

.PHONY: health
health: ## Check health status of all services
	@echo "Checking service health..."
	@$(DC) $(DC_FILES) ps

.PHONY: shell
shell: ## Open shell in a service (usage: make shell SERVICE=auth-service)
	@if [ -z "$(SERVICE)" ]; then \
		echo "Usage: make shell SERVICE=<service-name>"; \
		exit 1; \
	fi
	@$(DC) $(DC_FILES) exec $(SERVICE) sh

.PHONY: mysql
mysql: ## Connect to MySQL CLI
	@docker exec -it mysql mysql -u smileuser -p

.PHONY: redis-cli
redis-cli: ## Connect to Redis CLI
	@docker exec -it redis redis-cli

.PHONY: backup-db
backup-db: ## Backup MySQL database
	@echo "Creating database backup..."
	@mkdir -p $(DOCKER_DIR)/backups
	@docker exec mysql mysqldump -u root -p$$(grep MYSQL_ROOT_PASSWORD $(DOCKER_DIR)/.env | cut -d '=' -f2) --all-databases > $(DOCKER_DIR)/backups/backup_$$(date +%Y%m%d_%H%M%S).sql
	@echo "Backup created in $(DOCKER_DIR)/backups/ directory"

.PHONY: restore-db
restore-db: ## Restore MySQL database (usage: make restore-db FILE=docker/backups/backup.sql)
	@if [ -z "$(FILE)" ]; then \
		echo "Usage: make restore-db FILE=<backup-file>"; \
		exit 1; \
	fi
	@echo "Restoring database from $(FILE)..."
	@docker exec -i mysql mysql -u root -p$$(grep MYSQL_ROOT_PASSWORD $(DOCKER_DIR)/.env | cut -d '=' -f2) < $(FILE)
	@echo "Database restored"

.PHONY: dev
dev: start ## Start all services for development (alias for start)

.PHONY: prod
prod: ## Start all services in production mode
	@echo "Starting in production mode..."
	@$(MAKE) start

.PHONY: update
update: pull build restart ## Update images, rebuild, and restart

.PHONY: validate
validate: ## Validate docker-compose files
	@echo "Validating compose files..."
	@$(DC) $(DC_FILES) config > /dev/null
	@echo "All compose files are valid"
