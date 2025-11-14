#!/usr/bin/env bash
set -euo pipefail

# Source common formatting functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

# ============================================================================
# CONFIG
# ============================================================================

CLUSTER_NAME="${CLUSTER_NAME:-ldp}"

# ============================================================================
# DELETE CLUSTER
# ============================================================================

section "Deleting Kind Cluster"

if kind get clusters 2>/dev/null | grep -qx "$CLUSTER_NAME"; then
  run_step "Deleting cluster '$CLUSTER_NAME'" \
    kind delete cluster --name "$CLUSTER_NAME"
else
  ok "Cluster '$CLUSTER_NAME' does not exist"
fi
