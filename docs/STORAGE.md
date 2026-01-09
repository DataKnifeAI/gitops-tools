# Harbor Storage Configuration

This document describes the storage configuration for Harbor components.

## Current Storage Allocation

| Component | Size | Purpose | Notes |
|-----------|------|---------|-------|
| **Registry** | 400Gi | Container images | Main storage for all container images (80% of 500GB) |
| **Chartmuseum** | 50Gi | Helm charts | Stores Helm chart artifacts (10% of 500GB) |
| **Trivy** | 40Gi | Vulnerability scans | Stores vulnerability scan data (8% of 500GB) |
| **Jobservice** | 5Gi | Job data | Temporary job data and logs (1% of 500GB) |
| **Redis** | 5Gi | Cache | Redis data and cache (1% of 500GB) |
| **Database** | 1Gi | Database | Note: PostgreSQL has separate 20Gi x 2 = 40Gi storage |
| **PostgreSQL** | 20Gi x 2 | Database | Primary + replica (40Gi total) |

**Total Harbor Storage**: 501Gi (plus 40Gi PostgreSQL = 541Gi total)

## Storage Class

- **Storage Class**: `truenas-nfs` (default)
- **Volume Expansion**: ✅ Supported (`allowVolumeExpansion: true`)
- **Access Mode**: ReadWriteOnce (RWO)

## Registry Storage Considerations

The registry component stores all container images. Storage requirements depend on:

- **Number of images**: More images = more storage needed
- **Image sizes**: Larger images (e.g., ML models, databases) need more space
- **Retention policies**: How long images are kept
- **Proxy cache usage**: DockerHub proxy cache also uses registry storage
- **Tag policies**: Multiple tags per image increase storage

### Recommended Sizes

- **Development/Testing**: 20-50Gi
- **Small Production**: 100-200Gi
- **Medium Production**: 200-500Gi
- **Large Production**: 500Gi-2Ti or more

## Expanding Storage

### Option 1: Update HelmChart (Recommended for GitOps)

Update `harbor/base/harbor-helmchart.yaml`:

```yaml
persistence:
  persistentVolumeClaim:
    registry:
      size: 100Gi  # Increase as needed
```

Commit and push. Fleet will update the HelmChart, and Harbor will recreate the PVC with the new size.

⚠️ **Warning**: Recreating the PVC will delete existing data unless `resourcePolicy: "keep"` is set. Consider backing up important images first.

### Option 2: Expand Existing PVC (No Data Loss)

If the storage class supports volume expansion (truenas-nfs does), you can expand the PVC directly:

```bash
# Expand registry PVC
kubectl patch pvc harbor-registry -n managed-tools \
  -p '{"spec":{"resources":{"requests":{"storage":"100Gi"}}}}'

# Wait for expansion to complete
kubectl wait --for=condition=FileSystemResizePending pvc/harbor-registry -n managed-tools --timeout=5m

# Restart registry pod to apply new size
kubectl rollout restart deployment harbor-registry -n managed-tools
```

### Option 3: Manual PVC Expansion

1. Edit the PVC:
   ```bash
   kubectl edit pvc harbor-registry -n managed-tools
   ```

2. Update the `spec.resources.requests.storage` field

3. Wait for expansion to complete

4. Restart the registry pod if needed

## Monitoring Storage Usage

### Check PVC Sizes

```bash
kubectl get pvc -n managed-tools -o custom-columns=NAME:.metadata.name,SIZE:.spec.resources.requests.storage,USED:.status.capacity.storage
```

### Check Storage Usage Inside Pods

```bash
# Registry storage usage
kubectl exec -n managed-tools deployment/harbor-registry -c registry -- df -h /storage

# Chartmuseum storage usage
kubectl exec -n managed-tools deployment/harbor-chartmuseum -c chartmuseum -- df -h /chart_storage

# Trivy storage usage
kubectl exec -n managed-tools statefulset/harbor-trivy -c trivy -- df -h /var/lib/trivy
```

### Harbor UI

1. Go to Harbor UI: https://harbor.dataknife.net
2. Navigate to **Administration** → **Registries**
3. Check storage usage in project statistics

## Storage Best Practices

1. **Set retention policies**: Automatically clean up old images
2. **Monitor usage**: Set up alerts for storage thresholds
3. **Regular cleanup**: Remove unused images and tags
4. **Use proxy cache wisely**: DockerHub proxy cache can consume significant storage
5. **Plan for growth**: Allocate more storage than initially needed
6. **Backup strategy**: Regular backups of important images

## Troubleshooting

### PVC Full

If a PVC is full:

1. **Immediate**: Expand the PVC using Option 2 or 3 above
2. **Cleanup**: Remove unused images and tags
3. **Review**: Check retention policies and adjust if needed

### Storage Class Issues

If storage class doesn't support expansion:

1. Check storage class: `kubectl get storageclass truenas-nfs -o yaml`
2. Look for `allowVolumeExpansion: true`
3. If false, you'll need to recreate the PVC (backup data first)

### Data Loss Prevention

When recreating PVCs:

1. Ensure `resourcePolicy: "keep"` is set in HelmChart
2. Backup important images before changes
3. Use Harbor's replication feature to sync to another registry
4. Export images before PVC recreation

## References

- [Harbor Storage Documentation](https://goharbor.io/docs/latest/administration/configuring-storage/)
- [Kubernetes Volume Expansion](https://kubernetes.io/docs/concepts/storage/persistent-volumes/#expanding-persistent-volumes-claims)
