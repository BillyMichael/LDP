# Default goal so `make` runs the cluster
.DEFAULT_GOAL := up

.PHONY: up down password restart kubeconfig info help


# ------------------------------------------------------------------------------
# Cluster Lifecycle
# ------------------------------------------------------------------------------

up: ## Create the kind cluster
	@bash cluster/cluster-up.sh

down: ## Delete the kind cluster
	@bash cluster/cluster-down.sh

restart: ## Restart the cluster
	@$(MAKE) --no-print-directory down
	@$(MAKE) --no-print-directory up


# ------------------------------------------------------------------------------
# Utilities
# ------------------------------------------------------------------------------

kubeconfig: ## Export updated kubeconfig
	@kind export kubeconfig --name ldp >/dev/null

info: ## Show Local Development Platform info
	@bash cluster/show-info.sh


# ------------------------------------------------------------------------------
# Help
# ------------------------------------------------------------------------------

help: ## Show this help
	@printf "\nLocal Development Platform Make Commands\n"
	@printf "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n"
	@awk 'BEGIN {FS=":.*##"; printf "Usage: make <target>\n\nAvailable targets:\n"} \
		/^[a-zA-Z0-9_-]+:.*##/ \
		{ printf "  %-15s %s\n", $$1, $$2 }' $(MAKEFILE_LIST)
	@printf "\n"
