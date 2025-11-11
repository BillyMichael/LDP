# Default goal so `make` alone runs the cluster
.DEFAULT_GOAL := up

.PHONY: up down password restart kubeconfig info

# Create the kind cluster
up:
	@echo "🚀 Creating kind cluster 'ldp'..."
	@bash cluster/cluster-up.sh

# Delete the kind cluster
down:
	@echo "🗑️  Deleting kind cluster 'ldp'..."
	@kind delete cluster --name ldp || true

password:
	@kubectl -n argocd get secret argocd-initial-admin-secret \
		-o jsonpath="{.data.password}" | base64 -d && echo

restart: down up

kubeconfig:
	@echo "⚙️  Updating kubeconfig for cluster 'ldp'..."
	@kind export kubeconfig --name ldp

info:
	@bash cluster/show-info.sh