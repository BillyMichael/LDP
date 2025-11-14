# Local Developer Platform

A local Kubernetes development platform using kind and ArgoCD.

## Prerequisites

- docker or podman
- kubectl
- kind

## Usage

```bash
# Create the cluster
make up

# Get ArgoCD admin password
make password

# Delete the cluster
make down

# Show cluster info
make info
```
