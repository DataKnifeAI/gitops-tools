# Authentik Secrets

Authentik (`authentik/overlays/prd-apps`) needs two secrets in the `authentik` namespace on **prd-apps**. Create them **before** Fleet deploys the bundle.

## 1. authentik-postgres-credentials

Used by CloudNativePG to bootstrap the `authentik` database. Must contain `username` and `password`.

## 2. authentik-env

Loaded into the server and worker pods as environment variables (`envFrom`). Non-secret settings (database host, name, user) live in the HelmChart values.

| Key | Purpose |
|-----|---------|
| `AUTHENTIK_SECRET_KEY` | Signs sessions and tokens. Never change it after first start. |
| `AUTHENTIK_POSTGRESQL__PASSWORD` | Must match the password in `authentik-postgres-credentials` |
| `AUTHENTIK_BOOTSTRAP_EMAIL` | Email for the initial `akadmin` user |
| `AUTHENTIK_BOOTSTRAP_PASSWORD` | Initial `akadmin` password (only read on first start) |
| `AUTHENTIK_BOOTSTRAP_TOKEN` | Initial API token for `akadmin` (only read on first start) |

## Create both

```bash
kubectl --context prd-apps create namespace authentik --dry-run=client -o yaml | kubectl --context prd-apps apply -f -

DB_PASSWORD=$(openssl rand -base64 36 | tr -d '\n/+=')
SECRET_KEY=$(openssl rand -base64 60 | tr -d '\n')
ADMIN_PASSWORD=$(openssl rand -base64 24 | tr -d '\n/+=')
ADMIN_TOKEN=$(openssl rand -hex 32)

kubectl --context prd-apps -n authentik create secret generic authentik-postgres-credentials \
  --type=kubernetes.io/basic-auth \
  --from-literal=username=authentik \
  --from-literal=password="$DB_PASSWORD"

kubectl --context prd-apps -n authentik create secret generic authentik-env \
  --from-literal=AUTHENTIK_SECRET_KEY="$SECRET_KEY" \
  --from-literal=AUTHENTIK_POSTGRESQL__PASSWORD="$DB_PASSWORD" \
  --from-literal=AUTHENTIK_BOOTSTRAP_EMAIL='admin@dataknife.net' \
  --from-literal=AUTHENTIK_BOOTSTRAP_PASSWORD="$ADMIN_PASSWORD" \
  --from-literal=AUTHENTIK_BOOTSTRAP_TOKEN="$ADMIN_TOKEN"
```

Retrieve the initial admin password later with:

```bash
kubectl --context prd-apps -n authentik get secret authentik-env \
  -o jsonpath='{.data.AUTHENTIK_BOOTSTRAP_PASSWORD}' | base64 -d; echo
```

## 3. cnpg-backup-rustfs (database backups)

S3 credentials for the Barman Cloud plugin, which backs up `authentik-postgres` to rustfs. Keys:
`ACCESS_KEY_ID` and `ACCESS_SECRET_KEY`. The same secret exists in every namespace that holds a
CNPG cluster.

```bash
kubectl --context prd-apps -n authentik create secret generic cnpg-backup-rustfs \
  --from-literal=ACCESS_KEY_ID="$S3_ACCESS_KEY" --from-literal=ACCESS_SECRET_KEY="$S3_SECRET_KEY"
```

## Database backups and restore

`authentik-postgres` archives WAL continuously and takes a daily base backup (10:00 UTC) to
`s3://rke2-backups/cnpg/prd-apps/authentik-postgres/` on rustfs (`https://rustfs.dataknife.net:30292`),
gzip, 14 day retention. Config: `authentik/overlays/prd-apps/objectstore.yaml` and the `plugins`
section of `postgres-cluster.yaml`. `max_slot_wal_keep_size: 1GB` keeps a broken replica's slot from
filling the 5Gi volume.

```bash
kubectl cnpg status authentik-postgres -n authentik
kubectl -n authentik get backups.postgresql.cnpg.io
kubectl cnpg backup authentik-postgres -n authentik --method=plugin --plugin-name=barman-cloud.cloudnative-pg.io
```

Restore: create a new Cluster with `bootstrap.recovery.source` set to an `externalClusters` entry
that uses plugin `barman-cloud.cloudnative-pg.io` with `barmanObjectName: authentik-postgres-rustfs`
and `serverName: authentik-postgres`. Then point the HelmChart's database host at the new `-rw`
service. A full example is in the gitops-core `cnpg-barman-cloud` README. The database password must
still match `AUTHENTIK_POSTGRESQL__PASSWORD`, because recovery restores the original roles.

## Lockout recovery

If `akadmin` is locked out, create a one-time recovery link from inside a server pod:

```bash
kubectl --context prd-apps -n authentik exec deploy/authentik-server -- ak create_recovery_key 10 akadmin
```

Open `https://auth.dataknife.net` followed by the printed path.
