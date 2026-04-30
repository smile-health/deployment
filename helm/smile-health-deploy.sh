#!/usr/bin/env bash
# smile-health deployment script
# Deploys all services to the smile-health namespace on badr-dev
# Usage: ./smile-health-deploy.sh [service]
#   service: auth|core|main|warehouse|sync|notification|frontend|all (default: all)

set -e

KUBECONFIG="${KUBECONFIG:-$HOME/.kube/config.badr-dev}"
NS="smile-health"
HV="$(cd "$(dirname "$0")" && pwd)"
CHART="$HV/smile-app-0.1.0-patched.tgz"

export KUBECONFIG

if [ ! -f "$CHART" ]; then
  echo "ERROR: Patched helm chart not found at $CHART"
  echo "See docs/06-helm-structure.md for details."
  exit 1
fi

deploy_service() {
  local name=$1
  local values=$2
  echo "→ Deploying $name..."
  helm upgrade --install "$name" "$CHART" \
    --namespace "$NS" \
    --values "$values" \
    --wait --timeout 120s
  echo "✓ $name deployed"
}

TARGET="${1:-all}"

case "$TARGET" in
  auth|all)
    deploy_service smile-health-auth-service "$HV/backend/smile-health-auth-service-dev-onprem.yaml"
    ;;&
  core|all)
    deploy_service smile-health-core "$HV/backend/smile-health-core-dev-onprem.yaml"
    ;;&
  main|all)
    deploy_service smile-health-main "$HV/backend/smile-health-main-dev-onprem.yaml"
    ;;&
  warehouse|all)
    deploy_service smile-health-warehouse-service "$HV/backend/smile-health-warehouse-service-dev-onprem.yaml"
    ;;&
  sync|all)
    deploy_service smile-health-sync-service "$HV/backend/smile-health-sync-service-dev-onprem.yaml"
    ;;&
  notification|all)
    deploy_service smile-health-notification "$HV/backend/smile-health-notification-dev-onprem.yaml"
    ;;&
  frontend|all)
    deploy_service smile-health-frontend "$HV/frontend/smile-health-frontend-dev.yaml"
    ;;&
  vs|all)
    echo "→ Applying VirtualService..."
    kubectl apply -f "$HV/backend/virtualservice/vs-smile-health-dev-onprem.yml"
    echo "✓ VirtualService applied"
    ;;
  *)
    echo "Unknown service: $TARGET"
    echo "Usage: $0 [auth|core|main|warehouse|sync|notification|frontend|vs|all]"
    exit 1
    ;;
esac

echo ""
echo "✓ Done. Check pod status:"
echo "  kubectl get pods -n $NS"
