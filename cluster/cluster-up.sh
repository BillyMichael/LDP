#!/usr/bin/env bash
set -euo pipefail

# Source common formatting functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

# ============================================================================
# CONFIG
# ============================================================================

CLUSTER_NAME="${CLUSTER_NAME:-ldp}"
KIND_CFG="${KIND_CFG:-cluster/cluster-config.yaml}"
ARGOCD_NS="${ARGOCD_NS:-orchestration}"
ARGOCD_CHART_DIR="${CHART_DIR:-platform-apps/orchestration/argocd}"
ARGOCD_RELEASE="${ARGOCD_RELEASE:-argocd}"
APPSET_FILE="${APPSET_FILE:-${ARGOCD_CHART_DIR}/templates/applicationsets-platform.yaml}"


# ============================================================================
# DETECT CONTAINER ENGINE
# ============================================================================

section "Detecting Container Engine"

if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
  ok "Using Docker"
  CE="docker"
elif command -v podman >/dev/null 2>&1; then
  ok "Using Podman"
  CE="podman"
  export KIND_EXPERIMENTAL_PROVIDER=podman
else
  error "Docker or Podman is required"
  exit 1
fi


# ============================================================================
# CHECK REQUIRED TOOLS
# ============================================================================

section "Checking Required Tools"

for tool in kind kubectl helm; do
  if command -v "$tool" >/dev/null 2>&1; then
    ok "$tool found"
  else
    error "$tool not found"
    exit 1
  fi
done


# ============================================================================
# CREATE KIND CLUSTER
# ============================================================================

section "Creating Kind Cluster"

if kind get clusters 2>/dev/null | grep -qx "$CLUSTER_NAME"; then
  ok "Cluster '$CLUSTER_NAME' already exists"
else
  run_step "Creating cluster '$CLUSTER_NAME'" \
    kind create cluster --name "$CLUSTER_NAME" --config "$KIND_CFG" --quiet
fi


# ============================================================================
# INSTALL ARGO CD
# ============================================================================

section "Installing Argo CD"

run_step "Adding Argo CD Helm repository" \
  helm repo add argo https://argoproj.github.io/argo-helm

run_step "Updating Helm repositories" \
  helm repo update

run_step "Installing Argo CD (core chart)" \
  helm upgrade --install "$ARGOCD_RELEASE" argo/argo-cd \
    --namespace "$ARGOCD_NS" \
    --create-namespace \
    --wait \
    --timeout=5m

run_step "Migrating to custom Argo CD chart" \
  helm upgrade --install "$ARGOCD_RELEASE" "$ARGOCD_CHART_DIR" \
    --namespace "$ARGOCD_NS" \
    --wait \
    --dependency-update \
    --timeout=5m


# ============================================================================
# WAIT FOR LLDAP SECRETS
# ============================================================================

section "Waiting for Authentication Provider"

LLDAP_NS="auth"
LLDAP_SECRETS=("admin" "maintainer" "user")

for SECRET in "${LLDAP_SECRETS[@]}"; do
  run_step "Waiting for '${SECRET}' credentials" \
    bash -c "
      for _ in {1..150}; do
        kubectl -n '$LLDAP_NS' get secret 'lldap-${SECRET}-credentials' >/dev/null 2>&1 && exit 0
        sleep 2
      done
      exit 1
    "
done

run_step "Waiting for Authelia to be Ready" \
  bash -c "
    for _ in {1..150}; do
      READY=\$(kubectl -n '$LLDAP_NS' get pods -l app.kubernetes.io/name=authelia \
        -o jsonpath='{.items[*].status.conditions[?(@.type==\"Ready\")].status}' 2>/dev/null)

      if [[ \"\$READY\" =~ ^(True|true)$ ]]; then
        exit 0
      fi

      sleep 2
    done

    exit 1
  "

# ============================================================================
# CONFIGURE COREDNS
# ============================================================================

section "Configuring CoreDNS (nip.io → Traefik)"

TRAEFIK_NS="core"
TRAEFIK_SVC="traefik"

run_step "Waiting for Traefik service" \
  bash -c "
    for _ in {1..30}; do
      kubectl -n '$TRAEFIK_NS' get service '$TRAEFIK_SVC' >/dev/null 2>&1 && exit 0
      sleep 2
    done
    exit 1
  "

TRAEFIK_IP="$(kubectl -n "$TRAEFIK_NS" get service "$TRAEFIK_SVC" -o jsonpath='{.spec.clusterIP}')"

run_step "Patching CoreDNS config" \
  bash -c "
    kubectl get configmap coredns -n kube-system -o jsonpath='{.data.Corefile}' |
      awk -v traefik_ip='$TRAEFIK_IP' '
        /^\.:[0-9]+ \{/ {
          print \$0
          print \"    hosts {\"
          print \"      \" traefik_ip \" 127.0.0.1.nip.io\"
          print \"      fallthrough\"
          print \"    }\"
          print \"    rewrite name regex (.+\\.)?127\\.0\\.0\\.1\\.nip\\.io 127.0.0.1.nip.io\"
          next
        }
        { print }
      ' > /tmp/coredns-corefile.txt

    kubectl create configmap coredns --from-file=Corefile=/tmp/coredns-corefile.txt \
      --dry-run=client -o yaml |
      kubectl apply -n kube-system -f -

    kubectl rollout restart deployment/coredns -n kube-system
  "


# ============================================================================
# FINAL INFO
# ============================================================================

bash cluster/show-info.sh
