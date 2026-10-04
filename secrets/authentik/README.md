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

## Lockout recovery

If `akadmin` is locked out, create a one-time recovery link from inside a server pod:

```bash
kubectl --context prd-apps -n authentik exec deploy/authentik-server -- ak create_recovery_key 10 akadmin
```

Open `https://auth.dataknife.net` followed by the printed path.
