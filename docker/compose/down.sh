#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=========================================="
echo "Smile Health Docker Compose Down"
echo "=========================================="
echo ""

echo "Stopping all services..."
docker compose -f "$SCRIPT_DIR/compose-tools.yml" -f "$SCRIPT_DIR/compose-services.yml" -f "$SCRIPT_DIR/compose-frontend.yml" down

echo ""
echo "=========================================="
echo "✓ All services stopped"
echo "=========================================="
echo ""
