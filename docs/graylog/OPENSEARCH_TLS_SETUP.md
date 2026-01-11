# Graylog + OpenSearch TLS/SSL Setup Guide

## Overview

This document describes the setup and lessons learned from configuring Graylog to communicate with OpenSearch over HTTPS with self-signed certificates in a Kubernetes environment.

## Architecture

- **Graylog**: Log aggregation and analysis platform
- **OpenSearch**: Search and analytics engine (Elasticsearch-compatible)
- **OpenSearch Kubernetes Operator**: Manages OpenSearch cluster lifecycle
- **cert-manager**: Manages TLS certificates (for webhooks)
- **Fleet GitOps**: Continuous deployment of Kubernetes resources

## Key Challenges and Solutions

### 1. OpenSearch Self-Signed Certificates

**Problem**: OpenSearch operator generates self-signed certificates with hostname `node-0.example.com`, but Graylog connects to `graylog-opensearch` service.

**Solution**: 
- Extract OpenSearch CA certificate from the OpenSearch pod
- Import CA certificate into Graylog's Java truststore
- Use custom truststore location (writable volume) since default cacerts is read-only

### 2. Java Truststore in Container Images

**Problem**: The default Java cacerts file (`/opt/java/openjdk/lib/security/cacerts`) is read-only in container images. Changes made by init containers don't persist.

**Solution**:
- Copy cacerts to a writable shared volume (`/shared/cacerts`)
- Configure Java to use custom truststore via `GRAYLOG_SERVER_JAVA_OPTS`
- Use `emptyDir` volume shared between init containers and main container

### 3. Init Container Permissions

**Problem**: `keytool` needs write access to create/modify the truststore file.

**Solution**:
- Run init container as root (`securityContext.runAsUser: 0`)
- Copy cacerts to writable location before importing certificate

### 4. Fleet Job Immutability

**Problem**: Fleet shows errors when trying to patch Jobs because `spec.template` is immutable.

**Solution**:
- This is expected behavior - Fleet cannot patch Jobs
- Jobs are still created and run successfully
- The error is non-blocking and can be safely ignored
- Document this in the Job annotations

### 5. Hostname Verification

**Problem**: Even with CA certificate in truststore, hostname verification fails because certificate is for `node-0.example.com` but connection is to `graylog-opensearch`.

**Current Status**: 
- Certificate trust is working (no more "certificate signed by unknown authority" errors)
- Hostname verification is disabled via `GRAYLOG_ELASTICSEARCH_VERIFY_SSL=false`
- Future improvement: Configure OpenSearch to generate certificates with correct hostname

## Implementation Details

### OpenSearch CA Certificate ConfigMap

**File**: `graylog/overlays/nprd-apps/opensearch-ca-configmap.yaml`

Extracts the CA certificate from OpenSearch pod and stores it in a ConfigMap:

```bash
kubectl exec graylog-opensearch-masters-0 -n managed-graylog -c opensearch \
  -- cat /usr/share/opensearch/config/root-ca.pem
```

### CA Import Init Container

**Purpose**: Import OpenSearch CA certificate into Java truststore before Graylog starts.

**Key Features**:
- Runs as root to have write permissions
- Copies default cacerts to writable shared volume
- Imports CA certificate using `keytool`
- Verifies certificate was imported successfully

**Location**: Added to StatefulSet via `graylog-secret-patch-job.yaml`

### Custom Truststore Configuration

**Java System Properties** (via `GRAYLOG_SERVER_JAVA_OPTS`):
```
-Djavax.net.ssl.trustStore=/shared/cacerts
-Djavax.net.ssl.trustStorePassword=changeit
```

**Why Custom Truststore?**
- Default cacerts is read-only in container image
- Changes don't persist between container restarts
- Shared volume allows init container to write, main container to read

### Shared Volume

**Volume**: `shared-data` (emptyDir)
- Used by `mongodb-uri-builder` init container (MongoDB URI)
- Used by `opensearch-ca-importer` init container (truststore)
- Mounted read-only in main Graylog container

## File Structure

```
graylog/overlays/nprd-apps/
├── opensearch-ca-configmap.yaml      # OpenSearch CA certificate
├── graylog-secret-patch-job.yaml     # Patches StatefulSet with secrets and CA import
└── kustomization.yaml                 # Includes ConfigMap in resources
```

## Manual Steps (if needed)

### Extract OpenSearch CA Certificate

```bash
# Get certificate from OpenSearch pod
kubectl exec graylog-opensearch-masters-0 -n managed-graylog -c opensearch \
  -- cat /usr/share/opensearch/config/root-ca.pem > /tmp/opensearch-ca.pem

# Update ConfigMap
kubectl create configmap opensearch-ca \
  --from-file=ca.crt=/tmp/opensearch-ca.pem \
  -n managed-graylog \
  --dry-run=client -o yaml | kubectl apply -f -
```

### Verify Certificate Import

```bash
# Check if certificate is in truststore
kubectl exec graylog-0 -n managed-graylog \
  -- keytool -list -keystore /shared/cacerts -storepass changeit -alias opensearch-ca
```

### Check Graylog Connection

```bash
# View Graylog logs for OpenSearch connection status
kubectl logs graylog-0 -n managed-graylog | grep -i "opensearch\|elasticsearch"
```

## Troubleshooting

### Certificate Trust Errors

**Symptom**: `None of the TrustManagers trust this certificate chain`

**Check**:
1. Verify CA certificate is in ConfigMap: `kubectl get configmap opensearch-ca -n managed-graylog`
2. Check init container logs: `kubectl logs graylog-0 -n managed-graylog -c opensearch-ca-importer`
3. Verify truststore exists: `kubectl exec graylog-0 -n managed-graylog -- ls -la /shared/cacerts`
4. Check JAVA_OPTS: `kubectl exec graylog-0 -n managed-graylog -- env | grep JAVA_OPTS`

### Hostname Verification Errors

**Symptom**: `Hostname graylog-opensearch not verified`

**Solution**: 
- Currently disabled via `GRAYLOG_ELASTICSEARCH_VERIFY_SSL=false`
- Future: Configure OpenSearch to generate certificates with correct hostname

### Fleet Job Errors

**Symptom**: `cannot patch "graylog-secret-patch" with kind Job: spec.template: Invalid value: field is immutable`

**Solution**: 
- This is expected - Fleet cannot patch Jobs
- Job still runs successfully
- Error is non-blocking and can be ignored

### Truststore Not Found

**Symptom**: `Keystore file does not exist: /shared/cacerts`

**Check**:
1. Verify init container completed: `kubectl logs graylog-0 -n managed-graylog -c opensearch-ca-importer`
2. Check shared volume mount: `kubectl describe pod graylog-0 -n managed-graylog | grep -A 5 "shared-data"`
3. Verify init container has shared-data mount

## Best Practices

1. **Use ConfigMaps for CA Certificates**: Store CA certificates in ConfigMaps for easy updates
2. **Shared Volumes for Init Containers**: Use `emptyDir` volumes to share data between init containers and main container
3. **Run Init Containers as Root**: When modifying system files (like truststore), run as root
4. **Verify Certificate Import**: Always verify certificate was successfully imported
5. **Document Fleet Limitations**: Document that Fleet Job errors are expected and non-blocking

## Future Improvements

1. **Proper Hostname in Certificates**: Configure OpenSearch operator to generate certificates with service hostname
2. **Certificate Rotation**: Automate CA certificate updates when OpenSearch certificates rotate
3. **Truststore Management**: Consider using a dedicated truststore management tool
4. **Hostname Verification**: Re-enable hostname verification once certificates have correct hostnames

## References

- [Graylog Documentation](https://go2docs.graylog.org/)
- [OpenSearch Kubernetes Operator](https://opensearch.org/docs/latest/install-and-configure/install-opensearch/kubernetes/)
- [Java Keytool Documentation](https://docs.oracle.com/javase/8/docs/technotes/tools/unix/keytool.html)
- [Kubernetes Init Containers](https://kubernetes.io/docs/concepts/workloads/pods/init-containers/)

## Related Files

- `graylog/overlays/nprd-apps/opensearch-ca-configmap.yaml` - CA certificate ConfigMap
- `graylog/overlays/nprd-apps/graylog-secret-patch-job.yaml` - StatefulSet patching job
- `graylog/overlays/nprd-apps/kustomization.yaml` - Kustomize configuration
- `graylog/base/opensearch-cluster.yaml` - OpenSearch cluster definition
