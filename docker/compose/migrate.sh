#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")/backend"

echo "=========================================="
echo "Database Migration & Seeding"
echo "=========================================="
echo ""

COMMAND="${1:-migrate}"

case "$COMMAND" in
  migrate)
    echo "Running database migrations..."
    echo ""
    
    echo "→ Migrating core..."
    cd "$BACKEND_DIR/apps/core" && npm run db:migrate
    echo "✓ core migration complete"
    echo ""
    
    echo "→ Migrating main..."
    cd "$BACKEND_DIR/apps/main" && npm run db:migrate
    echo "✓ main migration complete"
    echo ""
    
    echo "→ Migrating sync-service..."
    cd "$BACKEND_DIR/apps/sync-service" && npm run db:migrate
    echo "✓ sync-service migration complete"
    echo ""
    
    echo "→ Migrating notification..."
    cd "$BACKEND_DIR/apps/notification" && npm run migrate
    echo "✓ notification migration complete"
    echo ""
    
    echo "=========================================="
    echo "✓ All migrations completed!"
    echo "=========================================="
    ;;
    
  seed)
    echo "Running database seeding..."
    echo ""
    
    echo "→ Seeding core..."
    cd "$BACKEND_DIR/apps/core" && npm run db:seed -- --seed
    echo "✓ core seeding complete"
    echo ""
    
    echo "→ Seeding main..."
    cd "$BACKEND_DIR/apps/main" && npm run view:migrate
    echo "✓ main seeding complete"
    echo ""
    
    echo "=========================================="
    echo "✓ All seeding completed!"
    echo "=========================================="
    ;;
    
  *)
    echo "Usage: $0 [migrate|seed]"
    echo ""
    echo "Commands:"
    echo "  migrate  - Run all database migrations"
    echo "  seed     - Run all database seeding"
    exit 1
    ;;
esac
