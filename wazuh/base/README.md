# Wazuh Base Deployment

This directory contains the base Wazuh deployment configuration using Kubernetes manifests.

## Overview

Wazuh consists of three main components:
- **Wazuh Indexer**: Stores and indexes security data (based on OpenSearch)
- **Wazuh Server (Manager)**: Analyzes data from agents and triggers alerts
- **Wazuh Dashboard**: Web UI for visualizing and managing security events

## Getting Wazuh Kubernetes Manifests

Wazuh provides official Kubernetes manifests that need to be obtained from the [Wazuh Kubernetes repository](https://github.com/wazuh/wazuh-kubernetes).

### Step 1: Clone the Repository

```bash
# Clone the Wazuh Kubernetes repository
git clone https://github.com/wazuh/wazuh-kubernetes.git
cd wazuh-kubernetes

# Review the available deployment configurations
ls -la
```

### Step 2: Extract Required Manifests

The Wazuh Kubernetes repository contains manifests for:
- Wazuh Indexer (OpenSearch-based)
- Wazuh Server/Manager
- Wazuh Dashboard (Kibana-based)

You'll need to adapt these manifests to:
1. Use the `managed-tools` namespace
2. Add Kustomize labels (`app: wazuh`, `managed-by: gitops`)
3. Configure storage classes (`truenas-nfs`)
4. Set resource limits and requests
5. Configure TLS certificates

### Step 3: Generate Certificates

Wazuh components require TLS certificates for secure communication. Use the certificate generation script:

```bash
# From the repository root
./scripts/generate-wazuh-certificates.sh
```

This script:
- Downloads the Wazuh installation assistant
- Generates certificates for all components
- Creates Kubernetes secrets with the certificates

Alternatively, generate certificates manually:

```bash
# Download Wazuh installation assistant
curl -sO https://packages.wazuh.com/4.14/wazuh-install.sh
chmod 744 wazuh-install.sh

# Generate certificates only
./wazuh-install.sh -g

# This creates wazuh-install-files.tar with certificates
# Extract and create Kubernetes secrets
```

## Component Configuration

### Wazuh Indexer

The Indexer requires:
- **Persistent Storage**: StatefulSet with PVC for data persistence
- **Storage Class**: `truenas-nfs` (configured in overlay)
- **Resources**: Minimum 4GB memory, 2 CPU cores
- **TLS Certificates**: Required for secure communication

### Wazuh Server

The Server requires:
- **Persistent Storage**: StatefulSet with PVC for logs and configuration
- **Storage Class**: `truenas-nfs` (configured in overlay)
- **Resources**: Minimum 2GB memory, 1 CPU core
- **TLS Certificates**: Required for secure communication
- **Indexer Connection**: Must connect to Wazuh Indexer service

### Wazuh Dashboard

The Dashboard requires:
- **No Persistent Storage**: Stateless deployment
- **Resources**: Minimum 1GB memory, 500m CPU
- **TLS Certificates**: Required for secure communication
- **Indexer Connection**: Must connect to Wazuh Indexer service
- **Ingress**: Configured to use wildcard certificate

## Secrets Management

Wazuh requires several secrets:

### 1. TLS Certificates Secret

```bash
# Create from generated certificates
kubectl create secret generic wazuh-certs \
  --from-file=wazuh-indexer.pem \
  --from-file=wazuh-indexer-key.pem \
  --from-file=wazuh-server.pem \
  --from-file=wazuh-server-key.pem \
  --from-file=wazuh-dashboard.pem \
  --from-file=wazuh-dashboard-key.pem \
  -n managed-tools
```

### 2. Wazuh Credentials Secret

```bash
# Create credentials secret
kubectl create secret generic wazuh-credentials \
  --from-literal=indexer-password='<secure-password>' \
  --from-literal=server-password='<secure-password>' \
  --from-literal=dashboard-password='<secure-password>' \
  -n managed-tools
```

**⚠️ Important**: Store passwords securely. Consider using Sealed Secrets for GitOps:

```bash
# Create SealedSecret (requires Sealed Secrets controller)
kubectl create secret generic wazuh-credentials \
  --from-literal=indexer-password='<password>' \
  -n managed-tools \
  --dry-run=client -o yaml | kubectl seal -o yaml > wazuh-credentials-sealed.yaml
```

## Ingress Configuration

The Dashboard ingress uses the existing wildcard certificate:

- **Host**: `wazuh.dataknife.net`
- **Certificate**: `wildcard-dataknife-net-tls` (must exist in namespace)
- **Ingress Class**: `nginx`

The wildcard certificate should already exist if Harbor is deployed. If not, generate it:

```bash
# From repository root
./scripts/generate-wildcard-cert.sh
```

## Storage Configuration

All persistent volumes use the `truenas-nfs` storage class, which is configured in the overlay for cluster-specific settings.

**Storage Requirements**:
- **Indexer**: 50GB+ (depends on retention policy)
- **Server**: 10GB+ (depends on log retention)

## Resource Requirements

Minimum recommended resources:

| Component | CPU Request | Memory Request | CPU Limit | Memory Limit |
|-----------|-------------|----------------|-----------|--------------|
| Indexer   | 2000m       | 4Gi            | 4000m     | 8Gi          |
| Server    | 1000m       | 2Gi            | 2000m     | 4Gi          |
| Dashboard | 500m        | 1Gi            | 1000m     | 2Gi          |

These can be adjusted in the overlay based on actual workload.

## Deployment Order

Components must be deployed in this order:

1. **Wazuh Indexer** - Must be running first
2. **Wazuh Server** - Connects to Indexer
3. **Wazuh Dashboard** - Connects to Indexer

Kubernetes will handle dependencies through service discovery, but ensure Indexer is ready before Server/Dashboard start.

## Reference Documentation

- [Wazuh Kubernetes Deployment Guide](https://documentation.wazuh.com/current/installation-guide/installation-alternatives/kubernetes-deployment.html)
- [Wazuh Kubernetes Configuration](https://documentation.wazuh.com/current/installation-guide/installation-alternatives/kubernetes-configuration.html)
- [Wazuh GitHub - Kubernetes](https://github.com/wazuh/wazuh-kubernetes)
- [Wazuh Indexer Documentation](https://documentation.wazuh.com/current/user-manual/wazuh-indexer/index.html)
- [Wazuh Server Documentation](https://documentation.wazuh.com/current/user-manual/wazuh-server/index.html)
- [Wazuh Dashboard Documentation](https://documentation.wazuh.com/current/user-manual/wazuh-dashboard/index.html)
