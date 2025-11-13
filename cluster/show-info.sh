#!/usr/bin/env bash
set -euo pipefail

LLDAP_NS="${LLDAP_NS:-auth}"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🎉 Local Development Platform Info"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "👥 User Credentials:"
echo ""

# Fetch credentials
if kubectl -n "${LLDAP_NS}" get secret lldap-admin-credentials >/dev/null 2>&1; then
  ADMIN_USER=$(kubectl -n "${LLDAP_NS}" get secret lldap-admin-credentials \
    -o jsonpath="{.data.id}" 2>/dev/null | base64 -d)
  ADMIN_PASS=$(kubectl -n "${LLDAP_NS}" get secret lldap-admin-credentials \
    -o jsonpath="{.data.password}" 2>/dev/null | base64 -d)
else
  ADMIN_USER="(not yet available)"
  ADMIN_PASS=""
fi

if kubectl -n "${LLDAP_NS}" get secret lldap-maintainer-credentials >/dev/null 2>&1; then
  MAINT_USER=$(kubectl -n "${LLDAP_NS}" get secret lldap-maintainer-credentials \
    -o jsonpath="{.data.id}" 2>/dev/null | base64 -d)
  MAINT_PASS=$(kubectl -n "${LLDAP_NS}" get secret lldap-maintainer-credentials \
    -o jsonpath="{.data.password}" 2>/dev/null | base64 -d)
else
  MAINT_USER="(not yet available)"
  MAINT_PASS=""
fi

if kubectl -n "${LLDAP_NS}" get secret lldap-user-credentials >/dev/null 2>&1; then
  USER_USER=$(kubectl -n "${LLDAP_NS}" get secret lldap-user-credentials \
    -o jsonpath="{.data.id}" 2>/dev/null | base64 -d)
  USER_PASS=$(kubectl -n "${LLDAP_NS}" get secret lldap-user-credentials \
    -o jsonpath="{.data.password}" 2>/dev/null | base64 -d)
else
  USER_USER="(not yet available)"
  USER_PASS=""
fi

printf " ┌─────────────┬──────────────────────┬──────────────────────┐\n"
printf " │ %-11s │ %-20s │ %-20s │\n" "Role" "Username" "Password"
printf " ├─────────────┼──────────────────────┼──────────────────────┤\n"
printf " │ %-11s │ %-20s │ %-20s │\n" "Admin" "${ADMIN_USER}" "${ADMIN_PASS}"
printf " │ %-11s │ %-20s │ %-20s │\n" "Maintainer" "${MAINT_USER}" "${MAINT_PASS}"
printf " │ %-11s │ %-20s │ %-20s │\n" "User" "${USER_USER}" "${USER_PASS}"
printf " └─────────────┴──────────────────────┴──────────────────────┘\n"
echo ""
echo "🌐 URLs:"
echo ""
printf " ┌──────────────┬────────────────────────────────────────────┐\n"
printf " │ %-12s │ %-42s │\n" "Service" "URL"
printf " ├──────────────┼────────────────────────────────────────────┤\n"
printf " │ %-12s │ %-42s │\n" "ArgoCD" "https://cd.host.docker.internal"
printf " │ %-12s │ %-42s │\n" "Authelia" "https://auth.host.docker.internal"
printf " │ %-12s │ %-42s │\n" "Gitea" "https://vcs.host.docker.internal"
printf " └──────────────┴────────────────────────────────────────────┘\n"
echo ""
echo "💡 Useful commands:"
echo ""
printf " ┌──────────────────┬────────────────────────────────────────┐\n"
printf " │ %-16s │ %-38s │\n" "Command" "Description"
printf " ├──────────────────┼────────────────────────────────────────┤\n"
printf " │ %-16s │ %-38s │\n" "make down" "Delete cluster"
printf " │ %-16s │ %-38s │\n" "make restart" "Restart cluster"
printf " │ %-16s │ %-38s │\n" "make kubeconfig" "Update kubeconfig"
printf " │ %-16s │ %-38s │\n" "make info" "Show ldp info e.g. URLs, credentials"
printf " └──────────────────┴────────────────────────────────────────┘\n"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
