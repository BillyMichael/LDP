#!/usr/bin/env bash
set -euo pipefail

# Source common formatting functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

# ============================================================================
# CONFIG
# ============================================================================

CLUSTER_NAME="${CLUSTER_NAME:-ldp}"
CONTEXT_NAME="kind-${CLUSTER_NAME}"
KIND_CFG="${KIND_CFG:-cluster/cluster-config.yaml}"
ARGOCD_NS="${ARGOCD_NS:-orchestration}"
ARGOCD_CHART_DIR="${CHART_DIR:-platform-apps/orchestration/argocd}"
ARGOCD_RELEASE="${ARGOCD_RELEASE:-argocd}"
APPSET_FILE="${APPSET_FILE:-${ARGOCD_CHART_DIR}/templates/applicationsets-platform.yaml}"


# ============================================================================
# DETECT CONTAINER ENGINE
# ============================================================================

section "Detecting Container Engine"

if [[ "${KIND_EXPERIMENTAL_PROVIDER:-}" == "podman" ]]; then
  if command -v podman >/dev/null 2>&1; then
    ok "Using Podman (via KIND_EXPERIMENTAL_PROVIDER)"
    CE="podman"
  else
    error "KIND_EXPERIMENTAL_PROVIDER=podman is set but Podman is not installed."
    exit 1
  fi

elif command -v podman >/dev/null 2>&1; then
  ok "Using Podman"
  CE="podman"
  export KIND_EXPERIMENTAL_PROVIDER=podman

elif command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
  if [ "$(docker info --format '{{.OperatingSystem}}')" = "Docker Desktop" ]; then
    error "Docker Desktop detected — not supported. Use Podman or Docker Engine."
    exit 1
  fi

  ok "Using Docker Engine"
  CE="docker"

else
  error "No supported container engine found (need Docker Engine or Podman)."
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

# Set kubectl context to the Kind cluster for safety
run_step "Setting kubectl context to '$CONTEXT_NAME'" \
  kubectl config use-context "$CONTEXT_NAME"


# ============================================================================
# INSTALL ARGO CD
# ============================================================================

section "Installing Argo CD"

run_step "Adding Argo CD Helm repository" \
  helm repo add argo https://argoproj.github.io/argo-helm --kube-context "$CONTEXT_NAME"

run_step "Updating Helm repositories" \
  helm repo update --kube-context "$CONTEXT_NAME"

run_step "Installing Argo CD (core chart)" \
  helm upgrade --install "$ARGOCD_RELEASE" argo/argo-cd \
    --kube-context "$CONTEXT_NAME" \
    --namespace "$ARGOCD_NS" \
    --create-namespace \
    --wait \
    --timeout=5m

run_step "Migrating to custom Argo CD chart" \
  helm upgrade --install "$ARGOCD_RELEASE" "$ARGOCD_CHART_DIR" \
    --kube-context "$CONTEXT_NAME" \
    --namespace "$ARGOCD_NS" \
    --wait \
    --dependency-update \
    --timeout=5m

# ============================================================================
# CONFIGURE COREDNS
# ============================================================================

section "Configuring CoreDNS (nip.io → Traefik)"

TRAEFIK_NS="core"
TRAEFIK_SVC="traefik"

run_step "Waiting for Traefik service" \
  bash -c "
    for _ in {1..30}; do
      kubectl --context '$CONTEXT_NAME' -n '$TRAEFIK_NS' get service '$TRAEFIK_SVC' >/dev/null 2>&1 && exit 0
      sleep 2
    done
    exit 1
  "

TRAEFIK_IP="$(kubectl --context "$CONTEXT_NAME" -n "$TRAEFIK_NS" get service "$TRAEFIK_SVC" -o jsonpath='{.spec.clusterIP}')"

run_step "Patching CoreDNS config" \
  bash -c "
    kubectl --context '$CONTEXT_NAME' get configmap coredns -n kube-system -o jsonpath='{.data.Corefile}' |
      awk -v traefik_ip='$TRAEFIK_IP' '
        /^\.:[0-9]+ \{/ {
          print \$0
          print \"    hosts {\"
          print \"      \" traefik_ip \" 127-0-0-1.nip.io\"
          print \"      fallthrough\"
          print \"    }\"
          print \"    rewrite name regex (.+)-127-0-0-1\\\\.nip\\\\.io 127-0-0-1.nip.io\"
          next
        }
        { print }
      ' > /tmp/coredns-corefile.txt

    kubectl --context '$CONTEXT_NAME' create configmap coredns --from-file=Corefile=/tmp/coredns-corefile.txt \
      --dry-run=client -o yaml |
      kubectl --context '$CONTEXT_NAME' apply -n kube-system -f -

    kubectl --context '$CONTEXT_NAME' rollout restart deployment/coredns -n kube-system
  "
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
        kubectl --context '$CONTEXT_NAME' -n '$LLDAP_NS' get secret 'lldap-${SECRET}-credentials' >/dev/null 2>&1 && exit 0
        sleep 2
      done
      exit 1
    "
done

run_step "Waiting for Authelia to be Ready" \
  bash -c "
    for _ in {1..150}; do
      READY=\$(kubectl --context '$CONTEXT_NAME' -n '$LLDAP_NS' get pods -l app.kubernetes.io/name=authelia \
        -o jsonpath='{.items[*].status.conditions[?(@.type==\"Ready\")].status}' 2>/dev/null)

      if [[ \"\$READY\" =~ ^(True|true)$ ]]; then
        exit 0
      fi

      sleep 2
    done

    exit 1
  "


# ============================================================================
# FINAL INFO
# ============================================================================

bash cluster/show-info.sh
