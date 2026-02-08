# Harbor Backup Script

Backs up all container images and Harbor settings before migration or major changes.
Skips DockerHub proxy cache (`dockerhub/`) and freya project (`freya/`) — those can be re-pulled on demand.

## Prerequisites

- `skopeo` - container image copy tool
- `curl`, `jq`
- Harbor admin credentials

## Usage

```bash
# Set credentials (admin password)
export HARBOR_URL=https://harbor.dataknife.net
export HARBOR_USER=admin
export HARBOR_PASS=YourAdminPassword

# Verify exclusions first (no download)
LIST_ONLY=1 ./scripts/harbor-backup.sh
# Check output/settings/repositories-excluded.txt and repositories-list.txt

# Run backup (creates harbor-backup-YYYYMMDD-HHMMSS/ by default)
./scripts/harbor-backup.sh

# Or specify output directory
./scripts/harbor-backup.sh /path/to/backup-dir
```

## Output

```
harbor-backup-YYYYMMDD-HHMMSS/
├── settings/
│   ├── systeminfo.json         # Harbor system info
│   ├── configurations.json     # System config
│   ├── projects.json           # Projects list
│   ├── registries.json         # Registry endpoints (DockerHub proxy, etc.)
│   ├── labels.json             # Labels
│   ├── repositories-all.txt    # All repos (before filter)
│   ├── repositories-excluded.txt  # dockerhub, freya — verify before backup
│   └── repositories-list.txt  # Repos to backup (iteration list)
└── images/
    ├── library_nginx_latest/     # OCI directory format per image:tag
    └── ...
```

## Restore

Use the restore script (reads repositories-list.txt and images/ from backup):

```bash
HARBOR_URL=https://harbor.dataknife.net HARBOR_USER=admin HARBOR_PASS=... \
  ./scripts/harbor-restore.sh /path/to/harbor-backup-YYYYMMDD-HHMMSS
```

Options:
- `DRY_RUN=1` — list what would be restored, no copy
- `SKIP_SSL=1` — for self-signed certs

## Migration to harbor namespace

Before applying the Harbor namespace + truenas-csi-nfs changes:

1. Run this backup script
2. Copy secrets to Harbor namespace:
   ```bash
   kubectl get secret harbor-credentials harbor-postgresql-credentials -n managed-tools -o yaml | \
     sed 's/namespace: managed-tools/namespace: harbor/' | \
     kubectl apply -f -
   ```
3. Create harbor namespace if needed (Fleet will create it from namespace.yaml)
4. Apply Fleet changes - Harbor will deploy to harbor namespace with truenas-csi-nfs
5. Restore images if needed (new PVCs = empty registry)
