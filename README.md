# GitOps Tools

GitOps repository for deploying managed Kubernetes tools to the `nprd-apps` cluster.

> **Note**: This project is built with [Cursor](https://cursor.sh) and Composer mode.

## Overview

This repository contains Kubernetes manifests and configurations for deploying managed tools in a dedicated namespace on the `nprd-apps` cluster.

## Tools

- **Harbor**: Container image registry and management platform

## Structure

```
.
├── README.md
├── .env.example                     # Template for Harbor credentials (copy to .env)
├── scripts/
│   ├── create-harbor-secrets.sh    # Create Harbor credentials secret
│   └── generate-wildcard-cert.sh   # Generate wildcard TLS certificate
├── secrets/
│   └── harbor/
│       ├── harbor-credentials.yaml.example  # YAML template for secrets (user reference)
│       └── README.md               # Secrets directory documentation
├── harbor/
│   └── namespace: nprd-apps/managed-tools
└── ...
```

## Cluster Information

- **Cluster**: nprd-apps
- **Namespace**: managed-tools (dedicated namespace for managed tools)

## Setup Instructions

### Prerequisites

1. `kubectl` configured to access your cluster
2. `openssl` installed (for certificate generation)
3. Access to create secrets in the `managed-tools` namespace

### Step 1: Generate Wildcard TLS Certificate

Generate a cluster-wide wildcard certificate for `*.dataknife.net`:

```bash
# Generate certificate and create Kubernetes secret
./scripts/generate-wildcard-cert.sh

# The script will:
# - Generate self-signed wildcard certificate (valid 10 years)
# - Create secret 'wildcard-dataknife-net-tls' in managed-tools namespace
# - Save certificate files to ./certs/ (gitignored)
```

**To apply to multiple clusters:**
```bash
# Apply to nprd-apps cluster
kubectl --context=nprd-apps create namespace managed-tools --dry-run=client -o yaml | kubectl --context=nprd-apps apply -f -
kubectl get secret wildcard-dataknife-net-tls -n managed-tools -o yaml | \
  sed 's/namespace: managed-tools/namespace: managed-tools/' | \
  kubectl --context=nprd-apps apply -f -

# Apply to prd-apps cluster
kubectl --context=prd-apps create namespace managed-tools --dry-run=client -o yaml | kubectl --context=prd-apps apply -f -
kubectl get secret wildcard-dataknife-net-tls -n managed-tools -o yaml | \
  sed 's/namespace: managed-tools/namespace: managed-tools/' | \
  kubectl --context=prd-apps apply -f -
```

### Step 2: Create Harbor Credentials Secret

Create encrypted Kubernetes secrets for Harbor credentials:

**Option A: Using .env file (Recommended)**

```bash
# 1. Copy the example file at project root
cp .env.example .env

# 2. Edit .env with your actual passwords
nano .env  # or vim .env

# 3. Create the secret (reads from .env automatically)
./scripts/create-harbor-secrets.sh
```

**Alternative: Using YAML file**

```bash
# 1. Copy the example YAML file
cp secrets/harbor/harbor-credentials.yaml.example secrets/harbor/harbor-credentials.yaml

# 2. Edit with your actual passwords
nano secrets/harbor/harbor-credentials.yaml

# 3. Apply the secret
kubectl apply -f secrets/harbor/harbor-credentials.yaml
```

**Option B: Interactive prompts**

```bash
# Script will prompt for passwords
./scripts/create-harbor-secrets.sh
```

**Option C: Manual creation**

```bash
kubectl create secret generic harbor-credentials \
  --from-literal=harborAdminPassword='<your-password>' \
  --from-literal=databasePassword='<your-db-password>' \
  --from-literal=redisPassword='<optional-redis-password>' \
  -n managed-tools
```

**⚠️ Important:**
- The `.env` file is gitignored and will never be committed
- Never commit actual passwords to git
- Change default passwords in production

### Step 3: Deploy via GitOps

Once secrets are created, Fleet will automatically deploy Harbor when:
1. The namespace `managed-tools` exists
2. The TLS secret `wildcard-dataknife-net-tls` exists
3. The credentials secret `harbor-credentials` exists
4. Fleet syncs the GitRepo

Monitor deployment:
```bash
kubectl get helmchart -n managed-tools
kubectl get pods -n managed-tools
kubectl get ingress -n managed-tools
```

## Usage

This repository follows GitOps principles. Changes to manifests in this repository will be automatically applied to the cluster by your GitOps operator (e.g., ArgoCD, Flux, Rancher Fleet).

The GitOps connection is configured to:
- Monitor the `harbor/base` path
- Deploy resources to the `managed-tools` namespace on the `nprd-apps` cluster
- Automatically sync changes when commits are pushed to the main branch

## Security

- **Secrets are encrypted** in Kubernetes (encrypted at rest)
- **Local .env file** is gitignored and never committed
- **No plaintext passwords** in git repository
- **Wildcard certificate** covers all `*.dataknife.net` subdomains

## Contributing

1. Make changes to manifests in the appropriate tool directory
2. Commit and push changes
3. The GitOps operator will automatically sync changes to the cluster

## Troubleshooting

**Secrets not found:**
```bash
# Verify secrets exist
kubectl get secrets -n managed-tools

# Recreate if needed
./scripts/create-harbor-secrets.sh
./scripts/generate-wildcard-cert.sh
```

**Harbor not deploying:**
```bash
# Check Fleet status
kubectl get gitrepo -n fleet-default
kubectl describe bundle -n fleet-default gitops-tools-nprd-apps-harbor-base
```
