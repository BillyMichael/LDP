#!/usr/bin/env bash
set -euo pipefail

CLUSTER_NAME="${CLUSTER_NAME:-ldp}"
KIND_CFG="${KIND_CFG:-cluster/cluster-config.yaml}"
ARGOCD_NS="${ARGOCD_NS:-orchestration}"
ARGOCD_CHART_DIR="${CHART_DIR:-bootstrap/argocd}"
ARGOCD_RELEASE="${ARGOCD_RELEASE:-argocd}"


# Detect container engine: prefer docker, fallback podman
if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
  CE="docker"
elif command -v podman >/dev/null 2>&1; then
  CE="podman"
  export KIND_EXPERIMENTAL_PROVIDER=podman
else
  echo "❌ Need docker or podman installed and running."
  exit 1
fi

# Check required tools
command -v kind >/dev/null 2>&1 || { echo "❌ kind not found"; exit 1; }
command -v kubectl >/dev/null 2>&1 || { echo "❌ kubectl not found"; exit 1; }
command -v helm >/dev/null 2>&1 || { echo "❌ helm not found"; exit 1; }

# Create Kind Cluster
if kind get clusters 2>/dev/null | grep -qx "${CLUSTER_NAME}"; then
  echo "→ Cluster '${CLUSTER_NAME}' already exists"
else
  echo "▶ Creating cluster '${CLUSTER_NAME}'..."
  kind create cluster --name "${CLUSTER_NAME}" --config "${KIND_CFG}" --quiet
  echo "✅ Cluster created"
fi

# Install Argo CD
echo "▶ Installing Argo CD..."
cd "${ARGOCD_CHART_DIR}" && helm dependency update >/dev/null 2>&1 && \
helm upgrade --install "${ARGOCD_RELEASE}" . \
  --namespace "${ARGOCD_NS}" \
  --create-namespace \
  --wait \
  --timeout=5m \

echo "✅ Argo CD installed"

# Display Access Information 
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🎉 Local Development Platform Ready!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "🔐 Argo CD Credentials:"
echo "   Username: admin"

if kubectl -n "${ARGOCD_NS}" get secret argocd-initial-admin-secret >/dev/null 2>&1; then
  ARGOCD_PASSWORD=$(kubectl -n "${ARGOCD_NS}" get secret argocd-initial-admin-secret \
    -o jsonpath="{.data.password}" 2>/dev/null | base64 -d)
  echo "   Password: ${ARGOCD_PASSWORD}"
else
  echo "   Password: (run 'make password' to retrieve)"
fi

echo ""
echo "🌐 Access Argo CD:"
echo "   kubectl port-forward -n argocd svc/argocd-server 8080:80"
echo "   Then visit: http://localhost:8080"
echo ""
echo "💡 Useful commands:"
echo "   make down      - Delete cluster"
echo "   make restart   - Restart cluster"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""