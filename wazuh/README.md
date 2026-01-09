# Wazuh Deployment

This directory contains the GitOps configuration for deploying Wazuh security monitoring platform to the `nprd-apps` cluster in the `managed-tools` namespace.

## Overview

Wazuh is an open-source security monitoring platform that provides:
- **XDR (Extended Detection and Response)**: Unified security monitoring
- **SIEM (Security Information and Event Management)**: Log analysis and correlation
- **Threat Detection**: Real-time threat identification
- **Compliance**: Regulatory compliance monitoring

### Components

- **Wazuh Indexer**: Stores and indexes security data (based on OpenSearch)
- **Wazuh Server (Manager)**: Analyzes data from agents and triggers alerts
- **Wazuh Dashboard**: Web UI for visualizing and managing security events

## Directory Structure

```
wazuh/
├── base/                      # Base Wazuh configuration
│   ├── fleet.yaml            # Base Fleet config (typically not deployed directly)
│   ├── kustomization.yaml    # Kustomize base
│   ├── README.md             # Base configuration documentation
│   ├── wazuh-indexer-*.yaml  # Indexer manifests
│   ├── wazuh-server-*.yaml   # Server manifests
│   └── wazuh-dashboard-*.yaml # Dashboard manifests
├── overlays/
│   └── nprd-apps/            # nprd-apps cluster overlay
│       ├── fleet.yaml        # Cluster-specific Fleet config with targeting
│       ├── kustomization.yaml
│       ├── storage-class-patch.yaml
│       └── resource-limits-patch.yaml
├── fleet.yaml                # Root-level Fleet config (alternative)
└── README.md                 # This file
```

## Prerequisites

Before deploying Wazuh, ensure:

1. **Namespace exists**: `managed-tools` namespace must exist
2. **Wildcard certificate**: `wildcard-dataknife-net-tls` secret must exist in `managed-tools` namespace
3. **Storage class**: `truenas-nfs` storage class must be available
4. **Wazuh manifests**: Official Wazuh Kubernetes manifests need to be obtained and adapted

### 1. Generate Wildcard Certificate

If not already created (e.g., for Harbor):

```bash
# From repository root
./scripts/generate-wildcard-cert.sh
```

### 2. Generate Wazuh Certificates

Wazuh components require TLS certificates for secure communication:

```bash
# From repository root
./scripts/generate-wazuh-certificates.sh
```

This script:
- Downloads the Wazuh installation assistant
- Generates certificates for Indexer, Server, and Dashboard
- Creates Kubernetes secrets with the certificates

### 3. Create Wazuh Credentials Secret

```bash
# Create credentials secret
kubectl create secret generic wazuh-credentials \
  --from-literal=indexer-password='<secure-password>' \
  --from-literal=server-password='<secure-password>' \
  --from-literal=dashboard-password='<secure-password>' \
  -n managed-tools
```

**⚠️ Important**: Store passwords securely. Consider using Sealed Secrets for GitOps.

## Getting Wazuh Kubernetes Manifests

The base manifests in `wazuh/base/` are placeholders. You need to obtain the actual manifests from the [Wazuh Kubernetes repository](https://github.com/wazuh/wazuh-kubernetes).

### Steps

1. **Clone the repository**:
   ```bash
   git clone https://github.com/wazuh/wazuh-kubernetes.git
   cd wazuh-kubernetes
   ```

2. **Review the structure**:
   - Identify manifests for Indexer, Server, and Dashboard
   - Note configuration requirements and dependencies

3. **Adapt manifests**:
   - Update namespace to `managed-tools`
   - Add labels: `app: wazuh`, `managed-by: gitops`
   - Configure storage class references (will be patched in overlay)
   - Set resource limits (will be patched in overlay)
   - Update service names and connections

4. **Replace placeholders**:
   - Replace placeholder files in `wazuh/base/` with actual manifests
   - Ensure all required ConfigMaps, Secrets, Services, and Deployments/StatefulSets are included

See `wazuh/base/README.md` for detailed instructions.

## Deployment

### Fleet GitRepo Configuration

Configure your Fleet GitRepo to monitor the overlay:

```yaml
apiVersion: fleet.cattle.io/v1alpha1
kind: GitRepo
metadata:
  name: gitops-tools
  namespace: fleet-default
spec:
  repo: https://github.com/your-org/gitops-tools
  branch: main
  paths:
    - wazuh/overlays/nprd-apps
```

Or monitor the root directory (Fleet will discover all bundles):

```yaml
spec:
  repo: https://github.com/your-org/gitops-tools
  branch: main
  # No paths specified - Fleet creates bundles for each directory
```

### Cluster Targeting

The overlay `fleet.yaml` targets the `nprd-apps` cluster using:

```yaml
targetCustomizations:
  - name: nprd-apps
    clusterSelector:
      matchLabels:
        management.cattle.io/cluster-display-name: nprd-apps
```

Update the label if your cluster uses different labels.

### Deployment Order

Components should be deployed in this order:

1. **Wazuh Indexer** - Must be running first
2. **Wazuh Server** - Connects to Indexer
3. **Wazuh Dashboard** - Connects to Indexer

Kubernetes will handle dependencies through service discovery, but ensure Indexer is ready before Server/Dashboard start.

## Monitoring Deployment

```bash
# Check Fleet status
kubectl get bundle -n fleet-default | grep wazuh
kubectl describe bundle wazuh-nprd-apps -n fleet-default

# Check Wazuh components
kubectl get pods -n managed-tools -l app=wazuh
kubectl get statefulsets -n managed-tools -l app=wazuh
kubectl get deployments -n managed-tools -l app=wazuh
kubectl get services -n managed-tools -l app=wazuh
kubectl get ingress -n managed-tools -l app=wazuh

# Check component logs
kubectl logs -n managed-tools -l app=wazuh,component=indexer
kubectl logs -n managed-tools -l app=wazuh,component=server
kubectl logs -n managed-tools -l app=wazuh,component=dashboard
```

## Accessing Wazuh Dashboard

Once deployed, access the Wazuh Dashboard at:

- **URL**: `https://wazuh.dataknife.net`
- **Default credentials**: 
  - Username: `admin`
  - Password: Set during certificate generation (or check `wazuh-credentials` secret)

## Storage

Persistent volumes are configured with:
- **Storage Class**: `truenas-nfs` (configured in overlay)
- **Indexer**: 50GB+ (depends on retention policy)
- **Server**: 10GB+ (depends on log retention)

## Resource Requirements

Minimum recommended resources (configured in overlay):

| Component | CPU Request | Memory Request | CPU Limit | Memory Limit |
|-----------|-------------|----------------|-----------|--------------|
| Indexer   | 2000m       | 4Gi            | 4000m     | 8Gi          |
| Server    | 1000m       | 2Gi            | 2000m     | 4Gi          |
| Dashboard | 500m        | 1Gi            | 1000m     | 2Gi          |

Adjust in `overlays/nprd-apps/resource-limits-patch.yaml` based on actual workload.

## Agent Deployment

After deploying Wazuh, you can enroll agents to monitor endpoints:

1. Access the Wazuh Dashboard
2. Navigate to **Agents** section
3. Generate enrollment tokens
4. Install Wazuh agents on endpoints
5. Enroll agents using the tokens

For agent installation instructions, see [Wazuh Agent Documentation](https://documentation.wazuh.com/current/installation-guide/wazuh-agent/index.html).

## Troubleshooting

### Components Not Starting

1. **Check certificates**: Ensure `wazuh-certs` secret exists with all required certificates
2. **Check credentials**: Ensure `wazuh-credentials` secret exists
3. **Check storage**: Verify PVCs are bound and storage class is available
4. **Check logs**: Review component logs for errors

### Dashboard Not Accessible

1. **Check ingress**: Verify ingress is created and configured correctly
2. **Check certificate**: Ensure `wildcard-dataknife-net-tls` secret exists
3. **Check service**: Verify `wazuh-dashboard` service is running
4. **Check DNS**: Ensure `wazuh.dataknife.net` resolves correctly

### Indexer Connection Issues

1. **Check service**: Verify `wazuh-indexer` service is accessible
2. **Check certificates**: Ensure TLS certificates are valid
3. **Check configuration**: Verify Server/Dashboard configs point to correct Indexer service

## Reference Documentation

- [Wazuh Documentation](https://documentation.wazuh.com/current/index.html)
- [Wazuh Kubernetes Deployment Guide](https://documentation.wazuh.com/current/installation-guide/installation-alternatives/kubernetes-deployment.html)
- [Wazuh Kubernetes Configuration](https://documentation.wazuh.com/current/installation-guide/installation-alternatives/kubernetes-configuration.html)
- [Wazuh GitHub - Kubernetes](https://github.com/wazuh/wazuh-kubernetes)
- [Wazuh Indexer Documentation](https://documentation.wazuh.com/current/user-manual/wazuh-indexer/index.html)
- [Wazuh Server Documentation](https://documentation.wazuh.com/current/user-manual/wazuh-server/index.html)
- [Wazuh Dashboard Documentation](https://documentation.wazuh.com/current/user-manual/wazuh-dashboard/index.html)

## Comparison with Harbor Deployment

| Aspect | Harbor | Wazuh |
|--------|--------|-------|
| **Deployment Method** | Helm Chart (HelmChart CRD) | Kubernetes Manifests + Kustomize |
| **Source** | `helm.goharbor.io` | GitHub: `wazuh/wazuh-kubernetes` |
| **Components** | Single Helm chart | Separate manifests per component |
| **Database** | External PostgreSQL | Embedded in Indexer (OpenSearch) |
| **Certificate Management** | Wildcard cert for ingress | Internal TLS + wildcard cert for ingress |
| **Storage** | Multiple PVCs | Indexer PVC (primary), Server PVC (secondary) |
