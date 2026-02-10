deployment/docker/compose/recreate.sh
#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=========================================="
echo "Smile Health Docker Compose Recreate"
echo "=========================================="
echo ""

echo "Stopping and removing all containers..."
docker compose -f "$SCRIPT_DIR/compose-tools.yml" -f "$SCRIPT_DIR/compose-services.yml" -f "$SCRIPT_DIR/compose-frontend.yml" down

echo ""
echo "Recreating containers from existing images..."
docker compose --env-file "$SCRIPT_DIR/../env/.env" --env-file "$SCRIPT_DIR/../env/frontend-web.env" -f "$SCRIPT_DIR/compose-tools.yml" -f "$SCRIPT_DIR/compose-services.yml" -f "$SCRIPT_DIR/compose-frontend.yml" up -d

echo ""
echo "=========================================="
echo "✓ All containers recreated successfully"
echo "=========================================="
echo ""
