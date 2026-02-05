#!/bin/bash

# Keycloak Realm Import Script
# Handles token acquisition and realm import with proper error handling

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_DIR="$SCRIPT_DIR/../env"

# Load environment variables from .env file
if [ -f "$ENV_DIR/.env" ]; then
    set -a
    source "$ENV_DIR/.env"
    set +a
fi

KEYCLOAK_URL="${KEYCLOAK_URL:-http://localhost:4080}"
KEYCLOAK_MGMT_URL="${KEYCLOAK_MGMT_URL:-http://localhost:9000}"
KEYCLOAK_ADMIN="${KEYCLOAK_ADMIN:-admin}"
KEYCLOAK_ADMIN_PASSWORD="${KEYCLOAK_ADMIN_PASSWORD:-admin}"
REALM_NAME="${REALM_NAME:-smile}"
REALM_FILE="${REALM_FILE:-$SCRIPT_DIR/smile-realm.json}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=========================================="
echo "Keycloak Realm Import"
echo "=========================================="
echo "Keycloak URL: $KEYCLOAK_URL"
echo "Admin User: $KEYCLOAK_ADMIN"
echo "Realm: $REALM_NAME"
echo "Realm File: $REALM_FILE"
echo ""

# Check if realm file exists
if [ ! -f "$REALM_FILE" ]; then
    echo -e "${RED}✘ Realm file not found: $REALM_FILE${NC}"
    exit 1
fi

# Wait for Keycloak to be ready
echo "Step 1: Waiting for Keycloak to be ready..."
for i in {1..60}; do
    HEALTH_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "${KEYCLOAK_MGMT_URL}/health" 2>/dev/null || echo "000")
    if [ "$HEALTH_STATUS" = "200" ]; then
        MASTER_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "${KEYCLOAK_URL}/realms/master" 2>/dev/null || echo "000")
        if [ "$MASTER_STATUS" = "200" ]; then
            echo -e "${GREEN}✓ Keycloak is ready${NC}"
            break
        fi
    fi
    if [ $i -eq 60 ]; then
        echo -e "${RED}✘ Keycloak health check timed out${NC}"
        exit 1
    fi
    if [ $((i % 10)) -eq 0 ]; then
        echo "  Waiting... ($i/60)"
    fi
    sleep 2
done
echo ""

# Get access token
echo "Step 2: Obtaining access token..."
TOKEN_RESPONSE=$(curl -s -X POST \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "username=${KEYCLOAK_ADMIN}" \
    -d "password=${KEYCLOAK_ADMIN_PASSWORD}" \
    -d "grant_type=password" \
    -d "client_id=admin-cli" \
    "${KEYCLOAK_URL}/realms/master/protocol/openid-connect/token" 2>/dev/null)

ACCESS_TOKEN=$(echo "$TOKEN_RESPONSE" | grep -o '"access_token":"[^"]*"' | cut -d'"' -f4 2>/dev/null || echo "")

if [ -z "$ACCESS_TOKEN" ]; then
    echo -e "${RED}✘ Failed to obtain access token${NC}"
    echo "Response: $TOKEN_RESPONSE"
    exit 1
fi

echo -e "${GREEN}✓ Access token obtained${NC}"
echo ""

# Check if realm exists
echo "Step 3: Checking if realm exists..."
REALM_STATUS=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $ACCESS_TOKEN" \
    "${KEYCLOAK_URL}/admin/realms/${REALM_NAME}" 2>/dev/null)

if [ "$REALM_STATUS" = "200" ]; then
    echo -e "${YELLOW}⚠ Realm '$REALM_NAME' already exists (HTTP 200)${NC}"
    echo "  To force re-import, delete the realm first via Keycloak admin console"
    echo "  URL: ${KEYCLOAK_URL}/admin/master/console/#/realms"
    exit 0
elif [ "$REALM_STATUS" = "404" ]; then
    echo -e "${GREEN}✓ Realm '$REALM_NAME' does not exist (HTTP 404), proceeding with import${NC}"
else
    echo -e "${YELLOW}⚠ Unexpected HTTP status: $REALM_STATUS${NC}"
    echo "  Proceeding anyway..."
fi
echo ""

# Import realm
echo "Step 4: Importing realm..."

# Create a temp file for response headers
TEMP_HEADERS=$(mktemp)

IMPORT_RESPONSE=$(curl -s -X POST \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $ACCESS_TOKEN" \
    -d "@$REALM_FILE" \
    -D "$TEMP_HEADERS" \
    "${KEYCLOAK_URL}/admin/realms" 2>/dev/null)

IMPORT_STATUS=$(grep -oP 'HTTP/[0-9.]+ \K[0-9]+' "$TEMP_HEADERS" 2>/dev/null || echo "unknown")
rm -f "$TEMP_HEADERS"

echo "  HTTP Status: $IMPORT_STATUS"
echo "  Response: $IMPORT_RESPONSE"

# Check response
if [ "$IMPORT_STATUS" = "201" ] || [ "$IMPORT_STATUS" = "204" ]; then
    echo -e "${GREEN}✓ Realm '$REALM_NAME' imported successfully${NC}"
elif echo "$IMPORT_RESPONSE" | grep -q '"error"\|"errorMessage"\|errorMessage'; then
    if echo "$IMPORT_RESPONSE" | grep -qi "conflict\|already.exists"; then
        echo -e "${YELLOW}⚠ Import conflict - realm may already exist with partial data${NC}"
        echo "  Response: $IMPORT_RESPONSE"
        echo ""
        echo "  To resolve:"
        echo "  1. Delete the realm via Keycloak admin console:"
        echo "     ${KEYCLOAK_URL}/admin/master/console/#/realms"
        echo "  2. Or reset Keycloak database:"
        echo "     docker compose stop keycloak"
        echo "     docker exec mysql mysql -uroot -p\$MYSQL_ROOT_PASSWORD -e 'DROP DATABASE IF EXISTS keycloak; CREATE DATABASE keycloak CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;'"
        echo "     docker compose start keycloak"
        exit 1
    else
        echo -e "${RED}✘ Import failed${NC}"
        echo "  Response: $IMPORT_RESPONSE"
        exit 1
    fi
else
    echo -e "${YELLOW}⚠ Unexpected response (HTTP $IMPORT_STATUS)${NC}"
    echo "  Response: $IMPORT_RESPONSE"
    exit 1
fi

echo ""
echo "=========================================="
echo -e "${GREEN}✓ Keycloak Realm Import Complete!${NC}"
echo "=========================================="
echo ""
echo "Keycloak Admin Console: ${KEYCLOAK_URL}/admin"
echo "Realm: $REALM_NAME"
