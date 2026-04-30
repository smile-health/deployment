#!/usr/bin/env bash
# smile-health migration + seed runner
# Runs all migrations and seeds in the correct order for a fresh database.
# Must be run AFTER all pods are Running and MySQL is ready.
#
# Usage: ./smile-health-migrate.sh

set -e

KUBECONFIG="${KUBECONFIG:-$HOME/.kube/config.badr-dev}"
NS="smile-health"

export KUBECONFIG

KC="kubectl --namespace $NS"

exec_pod() {
  local deploy=$1
  local cmd=$2
  echo "→ [$deploy] $cmd"
  $KC exec deploy/$deploy -- sh -c "cd /app && printenv > .env && $cmd"
  echo "✓ done"
}

echo "Waiting for pods to be ready..."
for deploy in smile-health-core smile-health-main smile-health-sync-service; do
  $KC wait deploy/$deploy --for=condition=Available --timeout=120s
done
echo ""

echo "=== Step 1: Core migrations ==="
exec_pod smile-health-core "bun src/cli.ts run-migrate"

echo ""
echo "=== Step 2: Core seeds (users, entities, workspaces) ==="
exec_pod smile-health-core "bun kysely seed:run"

echo ""
echo "=== Step 3: Main migrations (partial — may stop before ws_materials VIEW exists) ==="
exec_pod smile-health-main "bun src/cli.ts run-migrate" || true

echo ""
echo "=== Step 4: Main seeds (creates ws_materials, ws_entities VIEWs) ==="
exec_pod smile-health-main "bun kysely seed:run"

echo ""
echo "=== Step 5: Main migrations again (completes remaining after VIEWs exist) ==="
exec_pod smile-health-main "bun src/cli.ts run-migrate"

echo ""
echo "=== Step 6: Sync migrations ==="
exec_pod smile-health-sync-service \
  "bun -e \"import { runMigrations } from './src/common/infrastructure/database/index.ts'; runMigrations()\""

echo ""
echo "✓ All migrations and seeds complete."
echo "  Notification migrations run automatically on service startup."
echo ""
echo "  Next: reset Keycloak passwords if users were pre-seeded."
echo "  See docs/01-kubernetes-deployment.md Step 12."
