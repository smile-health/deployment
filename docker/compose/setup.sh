#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKER_DIR="$(dirname "$SCRIPT_DIR")"
ENV_DIR="$DOCKER_DIR/env"
VOLUMES_DIR="$DOCKER_DIR/volumes"
REBUILD=false
USE_GHCR=false
COMPOSE_BAKE=true
BUILD_BACKEND=true
BUILD_FRONTEND=true
INIT_MODE=false

for arg in "$@"; do
    case $arg in
        --rebuild)
            REBUILD=true
            ;;
        --ghcr)
            USE_GHCR=true
            ;;
        --backend-only)
            BUILD_BACKEND=true
            BUILD_FRONTEND=false
            ;;
        --frontend-only)
            BUILD_BACKEND=false
            BUILD_FRONTEND=true
            ;;
        --init)
            INIT_MODE=true
            ;;
    esac
done

INIT_MARKER="$VOLUMES_DIR/.setup-init-done"

echo "=========================================="
echo "Smile Health Docker Compose Setup"
if [ "$REBUILD" = true ]; then
    echo "(Rebuild Mode: Images will be rebuilt)"
fi
if [ "$INIT_MODE" = true ]; then
    echo "(Init Mode: Will run database and Keycloak initialization)"
elif [ ! -f "$INIT_MARKER" ]; then
    echo "(First run detected - will run initialization)"
    INIT_MODE=true
fi
echo "=========================================="
echo ""

echo "Step 1: Creating environment files..."
if [ ! -f "$DOCKER_DIR/env/.env" ]; then
    if [ -f "$ENV_DIR/.env.example" ]; then
        cp "$ENV_DIR/.env.example" "$DOCKER_DIR/env/.env"
        echo "✓ Created $DOCKER_DIR/env/.env"
    fi
fi

for env_example in "$ENV_DIR"/*.env.example; do
    if [ -f "$env_example" ]; then
        env_file="${env_example%.example}"
        if [ ! -f "$env_file" ]; then
            cp "$env_example" "$env_file"
            echo "✓ Created $(basename "$env_file")"
        fi
    fi
done
echo ""

echo "Step 1.5: Copying .npmrc to service directories..."
NPMRC_SOURCE="$SCRIPT_DIR/.npmrc"
if [ -f "$NPMRC_SOURCE" ]; then
    BACKEND_APPS_DIR="$(dirname "$(dirname "$DOCKER_DIR")")/backend/apps"
    for service_dir in "$BACKEND_APPS_DIR"/{auth-service,core,main,notification,sync-service,warehouse-service}; do
        if [ -d "$service_dir" ]; then
            cp "$NPMRC_SOURCE" "$service_dir/.npmrc"
            echo "✓ Copied .npmrc to $(basename "$service_dir")"
        fi
    done
else
    echo "⚠ .npmrc not found at $NPMRC_SOURCE - skipping"
fi
echo ""

echo "Step 2: Creating volume directories..."
mkdir -p "$VOLUMES_DIR"/{mysql,redis,rabbitmq,rabbitmq-logs,minio,zookeeper,zookeeper-logs,kafka,clickhouse,clickhouse-logs,risingwave}
echo "✓ Volume directories created"
echo ""

echo "Step 3: Creating Docker network..."
docker network create smile-network 2>/dev/null || echo "✓ Network already exists"
echo ""

if [ "$BUILD_BACKEND" = true ]; then
    if [ "$USE_GHCR" = true ]; then
        echo "Step 3.5: Checking GitHub Container Registry authentication..."
        if docker pull ghcr.io/smile-health/backend/auth-service:demo >/dev/null 2>&1; then
            echo "✓ Already authenticated with GHCR"
        else
            echo "Authentication required for GHCR"
            echo "Please provide your GitHub credentials"
            read -p "GitHub Username: " GITHUB_USERNAME
            read -sp "GitHub Personal Access Token (read:packages scope): " GITHUB_TOKEN
            echo ""
            echo "$GITHUB_TOKEN" | docker login ghcr.io -u "$GITHUB_USERNAME" --password-stdin
            if [ $? -eq 0 ]; then
                echo "✓ Successfully authenticated with GHCR"
            else
                echo "✘ Failed to authenticate with GHCR"
                exit 1
            fi
        fi
        echo ""
    fi

    if [ "$INIT_MODE" = true ]; then
        echo "Step 4: Starting MySQL for initialization..."
        docker compose -f "$SCRIPT_DIR/compose-tools.yml" up -d mysql
        echo "  ✓ MySQL container started"
        echo ""

        source "$ENV_DIR/.env"

        MYSQL_ROOT_PASSWORD="${MYSQL_ROOT_PASSWORD:-rootpassword}"
        MYSQL_USER="${MYSQL_USER:-smileuser}"
        MYSQL_PASSWORD="${MYSQL_PASSWORD:-smilepass}"

        echo "  - Waiting for MySQL to be ready..."
        for i in {1..30}; do
            if docker exec mysql mysqladmin ping -h localhost --silent 2>/dev/null; then
                echo "  ✓ MySQL is ready"
                break
            fi
            if [ $i -eq 30 ]; then
                echo "  ⚠ MySQL health check timed out"
                exit 1
            fi
            sleep 2
        done

        echo "Step 4.5: Creating additional databases..."

        echo "  - Creating smile_health_mapping database..."
        docker exec mysql mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -e "CREATE DATABASE IF NOT EXISTS smile_health_mapping CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;" 2>/dev/null || echo "  ⚠ Failed to create smile_health_mapping"
        docker exec mysql mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -e "GRANT ALL PRIVILEGES ON smile_health_mapping.* TO '$MYSQL_USER'@'%';" 2>/dev/null || echo "  ⚠ Failed to grant privileges on smile_health_mapping"
        echo "  ✓ smile_health_mapping database created"

        echo "  - Creating smile_health_notification database..."
        docker exec mysql mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -e "CREATE DATABASE IF NOT EXISTS smile_health_notification CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;" 2>/dev/null || echo "  ⚠ Failed to create smile_health_notification"
        docker exec mysql mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -e "GRANT ALL PRIVILEGES ON smile_health_notification.* TO '$MYSQL_USER'@'%';" 2>/dev/null || echo "  ⚠ Failed to grant privileges on smile_health_notification"
        echo "  ✓ smile_health_notification database created"

        echo "  - Creating keycloak database..."
        docker exec mysql mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -e "CREATE DATABASE IF NOT EXISTS keycloak CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;" 2>/dev/null || echo "  ⚠ Failed to create keycloak"
        docker exec mysql mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -e "CREATE USER IF NOT EXISTS 'keycloak'@'%' IDENTIFIED BY '${KEYCLOAK_DB_PASSWORD:-keycloak}';" 2>/dev/null || echo "  ⚠ Failed to create keycloak user"
        docker exec mysql mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -e "GRANT ALL PRIVILEGES ON keycloak.* TO 'keycloak'@'%';" 2>/dev/null || echo "  ⚠ Failed to grant privileges on keycloak"
        echo "  ✓ keycloak database created"

        docker exec mysql mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -e "FLUSH PRIVILEGES;" 2>/dev/null
        echo "  ✓ Privileges flushed"
        echo ""

        echo "Step 4.6: Importing Keycloak realm using kc.sh import..."

        # Run Keycloak import using the import command before starting services
        # MSYS_NO_PATHCONV=1 prevents Git Bash from converting paths
        MSYS_NO_PATHCONV=1 docker run --rm \
            --name keycloak-import \
            --network smile-network \
            -v "$SCRIPT_DIR/smile-realm.json:/opt/keycloak/data/import/smile-realm.json:ro" \
            -e KC_DB=mysql \
            -e KC_DB_URL=jdbc:mysql://mysql:3306/keycloak \
            -e KC_DB_USERNAME=keycloak \
            -e KC_DB_PASSWORD="${KEYCLOAK_DB_PASSWORD:-keycloak}" \
            -e KEYCLOAK_ADMIN="${KEYCLOAK_ADMIN:-admin}" \
            -e KEYCLOAK_ADMIN_PASSWORD="${KEYCLOAK_ADMIN_PASSWORD:-admin}" \
            quay.io/keycloak/keycloak:25.0.6 \
            import --file /opt/keycloak/data/import/smile-realm.json --override true 2>/dev/null || echo "  ⚠ Realm import may have failed or realm already exists"

        echo "  ✓ Keycloak import command completed"

        echo "  - Importing Keycloak users..."
        MSYS_NO_PATHCONV=1 docker run --rm \
            --name keycloak-users-import \
            --network smile-network \
            -v "$SCRIPT_DIR/smile-users.json:/opt/keycloak/data/import/smile-users.json:ro" \
            -e KC_DB=mysql \
            -e KC_DB_URL=jdbc:mysql://mysql:3306/keycloak \
            -e KC_DB_USERNAME=keycloak \
            -e KC_DB_PASSWORD="${KEYCLOAK_DB_PASSWORD:-keycloak}" \
            -e KEYCLOAK_ADMIN="${KEYCLOAK_ADMIN:-admin}" \
            -e KEYCLOAK_ADMIN_PASSWORD="${KEYCLOAK_ADMIN_PASSWORD:-admin}" \
            quay.io/keycloak/keycloak:25.0.6 \
            import --file /opt/keycloak/data/import/smile-users.json --override true 2>/dev/null || echo "  ⚠ Users import may have failed or users already exist"
        echo "  ✓ Keycloak users import command completed"
        echo ""

        # Stop MySQL to let compose manage it
        docker compose -f "$SCRIPT_DIR/compose-tools.yml" stop mysql
        echo "  ✓ MySQL stopped (will be restarted with full compose)"
        echo ""

        # Mark initialization as complete
        touch "$INIT_MARKER"
        echo "✓ Initialization marked as complete"
        echo ""
    else
        echo "  ℹ Skipping database and Keycloak initialization (already initialized)"
        echo "  Run with --init flag to force initialization"
        echo ""
    fi

    echo "Step 5: Starting all services..."
    # docker compose -f "$SCRIPT_DIR/compose-tools.yml" -f "$SCRIPT_DIR/compose-data.yml" -f "$SCRIPT_DIR/compose-services.yml" -f "$SCRIPT_DIR/compose-frontend.yml" up -d

    SERVICES_FILE="compose-services.yml"
    if [ "$USE_GHCR" = true ]; then
        SERVICES_FILE="compose-services-ghcr.yml"
        echo "  - Using GHCR images (compose-services-ghcr.yml)"
    fi

    if [ "$REBUILD" = true ]; then
        docker compose --env-file "$ENV_DIR/.env" -f "$SCRIPT_DIR/compose-tools.yml" -f "$SCRIPT_DIR/$SERVICES_FILE" up -d --build
    else
        docker compose --env-file "$ENV_DIR/.env" -f "$SCRIPT_DIR/compose-tools.yml" -f "$SCRIPT_DIR/$SERVICES_FILE" up -d
    fi

    echo "  - Waiting for services to be healthy (30-60 seconds)..."
    sleep 10
    echo ""

    echo "=========================================="
    echo "✓ Backend Setup Complete!"
    echo "=========================================="
    echo ""
    echo "Service Endpoints:"
    echo "  Core API:       http://localhost:4000"
    echo "  Auth Service:   http://localhost:4003"
    echo "  Main Service:   http://localhost:4004"
    echo "  Warehouse:      http://localhost:4008"
    echo ""
    echo "Infrastructure:"
    echo "  MySQL:          localhost:4306"
    echo "  Redis:          localhost:4379"
    echo "  RabbitMQ:       localhost:4672"
    echo "  RabbitMQ UI:    http://localhost:4673"
    echo "  Keycloak:       http://localhost:4080"
    echo "  MinIO Console:  http://localhost:4901"
    echo ""
    # echo "Data Services:"
    # echo "  Kafka:          localhost:4093"
    # echo "  ClickHouse:     http://localhost:4123"
    # echo "  RisingWave:     http://localhost:4691"
    # echo ""
    echo "Run 'docker compose ps' to check service status"
    echo "Run 'docker compose logs -f' to view logs"
    echo ""
else
    echo "Step 4: Skipping backend setup (--frontend-only mode)"
    echo ""
fi

if [ "$BUILD_FRONTEND" = true ]; then
    echo "Step 5: Setting up frontend..."
    echo "=========================================="
    echo "Smile Health Frontend Setup"
    echo "=========================================="
    echo ""

    FRONTEND_ENV="$ENV_DIR/frontend-web.env"
    FRONTEND_ENV_EXAMPLE="$ENV_DIR/frontend-web.env.example"

    if [ ! -f "$FRONTEND_ENV" ]; then
        if [ -f "$FRONTEND_ENV_EXAMPLE" ]; then
            cp "$FRONTEND_ENV_EXAMPLE" "$FRONTEND_ENV"
            echo "✓ Created $FRONTEND_ENV"
        else
            echo "✘ $FRONTEND_ENV_EXAMPLE not found"
            exit 1
        fi
    else
        echo "✓ Frontend environment file already exists"
    fi
    echo ""

    echo "Validating frontend environment variables..."
    REQUIRED_VARS=("NODE_ENV" "API_URL" "API_AUTH_URL")
    MISSING_VARS=()

    for var in "${REQUIRED_VARS[@]}"; do
        if ! grep -q "^$var=" "$FRONTEND_ENV"; then
            MISSING_VARS+=("$var")
        fi
    done

    if [ ${#MISSING_VARS[@]} -gt 0 ]; then
        echo "⚠ Missing required variables in $FRONTEND_ENV:"
        printf '  - %s\n' "${MISSING_VARS[@]}"
        echo "Please update $FRONTEND_ENV with required values"
    else
        echo "✓ All required environment variables present"
    fi
    echo ""

    echo "Loading environment variables..."
    set -a
    source "$FRONTEND_ENV"
    set +a
    echo "✓ Environment variables loaded"
    echo "  - NODE_ENV: $NODE_ENV"
    echo "  - API_URL: $API_URL"
    echo ""

    echo "Building and starting frontend service..."
    docker compose --env-file "$ENV_DIR/.env" --env-file "$FRONTEND_ENV" -f "$SCRIPT_DIR/compose-frontend.yml" up -d --build
    echo "✓ Frontend service started"
    echo ""

    echo "Waiting for frontend service to be healthy..."
    FRONTEND_CONTAINER=$(docker compose -f "$SCRIPT_DIR/compose-frontend.yml" ps -q frontend-web 2>/dev/null || echo "")

    if [ -z "$FRONTEND_CONTAINER" ]; then
        echo "⚠ Frontend container not found, skipping health check"
    else
        MAX_ATTEMPTS=30
        ATTEMPT=0
        while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
            if docker exec "$FRONTEND_CONTAINER" wget -q -O /dev/null http://localhost:3000 2>/dev/null; then
                echo "✓ Frontend service is healthy"
                break
            fi
            ATTEMPT=$((ATTEMPT + 1))
            if [ $ATTEMPT -lt $MAX_ATTEMPTS ]; then
                echo "  Waiting... ($ATTEMPT/$MAX_ATTEMPTS)"
                sleep 2
            fi
        done

        if [ $ATTEMPT -eq $MAX_ATTEMPTS ]; then
            echo "⚠ Frontend service health check timed out"
        fi
    fi
    echo ""

    echo "=========================================="
    echo "✓ Frontend Setup Complete!"
    echo "=========================================="
    echo ""
    echo "Frontend Access:"
    echo "  URL:                http://localhost:4001"
    echo "  Node Environment:   $NODE_ENV"
    echo ""
    echo "API Endpoints:"
    echo "  Core API:           $API_URL"
    echo "  Auth Service:       $API_AUTH_URL"
    echo ""
else
    echo "Step 5: Skipping frontend setup (--backend-only mode)"
    echo ""
fi
