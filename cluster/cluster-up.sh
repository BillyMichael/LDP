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
  kind create cluster --name "${CLUSTER_NAME}" --config "${KIND_CFG}" --quiet
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
  --wait \
  --timeout=5m \
  >/dev/null 2>&1

echo "✅ Argo CD installed"

echo "▶ Migrate to our Argo CD chart now CRDs are installed..."
helm upgrade --install "${ARGOCD_RELEASE}" ./platform-apps/orchestration/argocd \
  --namespace "${ARGOCD_NS}" \
  --wait \
  --timeout=5m \
  >/dev/null 2>&1

echo "✅ Argo CD Migration complete"

# Wait for LLDAP user secrets to be created
echo "▶ Waiting for LLDAP user secrets..."
LLDAP_NS="auth"
LLDAP_SECRETS=("lldap-admin-credentials" "lldap-maintainer-credentials" "lldap-user-credentials")

TIMEOUT=300
ELAPSED=0
for SECRET in "${LLDAP_SECRETS[@]}"; do
  while ! kubectl -n "${LLDAP_NS}" get secret "${SECRET}" >/dev/null 2>&1; do
    if [ ${ELAPSED} -ge ${TIMEOUT} ]; then
      echo "⚠️  Timeout waiting for secret '${SECRET}' in namespace '${LLDAP_NS}'"
      break
    fi
    sleep 2
    ELAPSED=$((ELAPSED + 2))
  done
done

echo "✅ LLDAP user secrets created"

# Display Access Information
bash cluster/show-info.sh