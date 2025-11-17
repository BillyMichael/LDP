#!/usr/bin/env bash
set -euo pipefail

# Source common formatting functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

LLDAP_NS="${LLDAP_NS:-auth}"

# ============================================================================
# HEADER
# ============================================================================

section "Local Development Platform Info"

subsection "User Credentials:"

# ============================================================================
# FETCH CREDENTIALS
# ============================================================================

get_secret_field() {
  local secret="$1"
  local field="$2"

  if kubectl -n "$LLDAP_NS" get secret "$secret" >/dev/null 2>&1; then
    kubectl -n "$LLDAP_NS" get secret "$secret" -o jsonpath="{.data.$field}" 2>/dev/null | base64 -d
  else
    printf "(not yet available)"
  fi
}

ADMIN_USER=$(get_secret_field "lldap-admin-credentials" "id")
ADMIN_PASS=$(get_secret_field "lldap-admin-credentials" "password")

MAINT_USER=$(get_secret_field "lldap-maintainer-credentials" "id")
MAINT_PASS=$(get_secret_field "lldap-maintainer-credentials" "password")

USER_USER=$(get_secret_field "lldap-user-credentials" "id")
USER_PASS=$(get_secret_field "lldap-user-credentials" "password")


# ============================================================================
# PRINT CREDENTIAL TABLE
# ============================================================================

printf "  ┌─────────────┬──────────────────────┬──────────────────────┐\n"
printf "  │ %-11s │ %-20s │ %-20s │\n" "Role" "Username" "Password"
printf "  ├─────────────┼──────────────────────┼──────────────────────┤\n"
printf "  │ %-11s │ %-20s │ %-20s │\n" "Admin"      "$ADMIN_USER" "$ADMIN_PASS"
printf "  │ %-11s │ %-20s │ %-20s │\n" "Maintainer" "$MAINT_USER" "$MAINT_PASS"
printf "  │ %-11s │ %-20s │ %-20s │\n" "User"       "$USER_USER"  "$USER_PASS"
printf "  └─────────────┴──────────────────────┴──────────────────────┘\n\n"


# ============================================================================
# URL TABLE
# ============================================================================

subsection "URLs:"

printf "  ┌──────────────┬────────────────────────────────────────────┐\n"
printf "  │ %-12s │ %-42s │\n" "Service" "URL"
printf "  ├──────────────┼────────────────────────────────────────────┤\n"
printf "  │ %-12s │ %-42s │\n" "ArgoCD"   "https://cd-127-0-0-1.nip.io"
printf "  │ %-12s │ %-42s │\n" "Authelia" "https://auth-127-0-0-1.nip.io"
printf "  │ %-12s │ %-42s │\n" "Gitea"    "https://vcs-127-0-0-1.nip.io"
printf "  └──────────────┴────────────────────────────────────────────┘\n\n"


# ============================================================================
# COMMANDS TABLE
# ============================================================================

subsection "Useful Commands:"

printf "  ┌──────────────────┬────────────────────────────────────────┐\n"
printf "  │ %-16s │ %-38s │\n" "Command" "Description"
printf "  ├──────────────────┼────────────────────────────────────────┤\n"
printf "  │ %-16s │ %-38s │\n" "make down"       "Delete cluster"
printf "  │ %-16s │ %-38s │\n" "make restart"    "Restart cluster"
printf "  │ %-16s │ %-38s │\n" "make kubeconfig" "Update kubeconfig"
printf "  │ %-16s │ %-38s │\n" "make info"       "Show LDP info"
printf "  └──────────────────┴────────────────────────────────────────┘\n\n"
