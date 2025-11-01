#!/usr/bin/env bash
set -euo pipefail

CLUSTER_NAME="${CLUSTER_NAME:-ldp}"
KIND_CFG="${KIND_CFG:-cluster/cluster-config.yaml}"
ARGOCD_NS="${ARGOCD_NS:-orchestration}"
ARGOCD_CHART_DIR="${CHART_DIR:-platform-apps/orchestration/argocd}"
ARGOCD_RELEASE="${ARGOCD_RELEASE:-argocd}"
APPSET_FILE="${APPSET_FILE:-${ARGOCD_CHART_DIR}/templates/applicationsets-platform.yaml}"

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
  kind create cluster --name "${CLUSTER_NAME}" --config "${KIND_CFG}" 
  echo "✅ Cluster created"
fi

# Install Argo CD
# Add Argo CD Helm repository
echo "▶ Adding Argo CD Helm repository..."
helm repo add argo https://argoproj.github.io/argo-helm >/dev/null 2>&1 || true
helm repo update >/dev/null 2>&1

# Install Argo CD
echo "▶ Installing Argo CD..."
helm upgrade --install "${ARGOCD_RELEASE}" argo/argo-cd \
  --namespace "${ARGOCD_NS}" \
  --create-namespace \
  --set server.ingress.enabled=false \
  --wait \
  --timeout=5m

echo "✅ Argo CD installed"

echo "▶ Migrate to our Argo CD chart now CRDs are installed..."
helm upgrade --install "${ARGOCD_RELEASE}" ./platform-apps/orchestration/argocd \
  --namespace "${ARGOCD_NS}" \
  --wait \
  --timeout=5m \
  >/dev/null 2>&1

echo "✅ Argo CD Migration complete"

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
echo "   kubectl port-forward -n orchestration svc/argocd-server 8080:80"
echo "   Then visit: http://localhost:8080"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "🔐 Authelia Users:"
echo "   Admin:"
echo "      Username: admin"
echo "      Password: admin"
echo ""
echo "   Platform Maintainer:"
echo "      Username: platformMaintainer"
echo "      Password: maintainer"
echo ""
echo "   Platform User:"
echo "      Username: platformUser"
echo "      Password: user"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "💡 Useful commands:"
echo "   make down      - Delete cluster"
echo "   make restart   - Restart cluster"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""