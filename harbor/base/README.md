# Harbor Deployment

This directory contains the base Harbor deployment configuration using Helm charts.

## TLS Certificate Setup

Since `harbor.dataknife.net` is only available internally, Let's Encrypt cannot be used. A wildcard certificate for `*.dataknife.net` is recommended for cluster-wide use.

### Option 1: Wildcard Certificate (Recommended)

Generate a cluster-wide wildcard certificate that can be used by multiple services:

```bash
# From the repository root
./scripts/generate-wildcard-cert.sh

# Or specify a different namespace
NAMESPACE=your-namespace ./scripts/generate-wildcard-cert.sh
```

This creates:
- A self-signed wildcard certificate for `*.dataknife.net` (valid for 10 years)
- Kubernetes secret `wildcard-dataknife-net-tls` in the specified namespace
- Certificate files in `./certs/` directory (gitignored)

To use in other namespaces, copy the secret:
```bash
kubectl get secret wildcard-dataknife-net-tls -n managed-tools -o yaml | \
  sed 's/namespace: managed-tools/namespace: <target-namespace>/' | \
  kubectl apply -f -
```

### Option 2: Harbor-Specific Certificate (Alternative)

If you prefer a Harbor-specific certificate:

```bash
# Generate self-signed certificate
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout harbor.key \
  -out harbor.crt \
  -subj "/CN=harbor.dataknife.net" \
  -addext "subjectAltName=DNS:harbor.dataknife.net,DNS:notary.harbor.dataknife.net"

# Create the TLS secret in the managed-tools namespace
kubectl create namespace managed-tools --dry-run=client -o yaml | kubectl apply -f -
kubectl create secret tls wildcard-dataknife-net-tls \
  --cert=harbor.crt \
  --key=harbor.key \
  -n managed-tools
```

**Note:** If using a Harbor-specific certificate, you must update the secret name in `harbor-helmchart.yaml` to match.

### Option 3: Internal CA Certificate (For Production)

If you have an internal CA, you can sign the wildcard certificate:

```bash
# Generate certificate signing request for wildcard
openssl req -new -newkey rsa:2048 -nodes \
  -keyout wildcard-dataknife-net.key \
  -out wildcard-dataknife-net.csr \
  -subj "/CN=*.dataknife.net/O=Dataknife Internal/L=Internal/ST=Internal/C=US" \
  -addext "subjectAltName=DNS:*.dataknife.net,DNS:dataknife.net"

# Sign with your internal CA (adjust paths as needed)
openssl x509 -req -in wildcard-dataknife-net.csr \
  -CA /path/to/ca.crt \
  -CAkey /path/to/ca.key \
  -CAcreateserial \
  -out wildcard-dataknife-net.crt \
  -days 3650 \
  -extensions v3_req \
  -extfile <(
    echo "[v3_req]"
    echo "subjectAltName=DNS:*.dataknife.net,DNS:dataknife.net"
  )

# Create the TLS secret
kubectl create namespace managed-tools --dry-run=client -o yaml | kubectl apply -f -
kubectl create secret tls wildcard-dataknife-net-tls \
  --cert=wildcard-dataknife-net.crt \
  --key=wildcard-dataknife-net.key \
  -n managed-tools
```

## Important Notes

- The TLS secret must be created **before** Harbor is deployed
- The secret name must be exactly `wildcard-dataknife-net-tls` as specified in the HelmChart configuration
- The wildcard certificate (`*.dataknife.net`) covers:
  - `harbor.dataknife.net`
  - `notary.harbor.dataknife.net`
  - Any other `*.dataknife.net` subdomain
- For self-signed certificates, clients will need to trust the certificate or CA
- The wildcard certificate approach allows reuse across multiple services in the cluster

## Credentials Management

**⚠️ Passwords are no longer stored in plaintext in the HelmChart!**

The Harbor HelmChart has been configured to use empty passwords by default. You must create a Kubernetes Secret with the credentials:

### Quick Setup

```bash
# Create the secret interactively
./scripts/create-harbor-secrets.sh

# Or create manually
kubectl create secret generic harbor-credentials \
  --from-literal=harborAdminPassword='<your-password>' \
  --from-literal=databasePassword='<your-db-password>' \
  -n managed-tools
```

### Using the Credentials

After creating the secret, the Harbor HelmChart is configured to use the `harbor-credentials` secret directly via `existingSecret`. 
No HelmChartConfig is required for passwords - just ensure the secret exists:
```bash
# Create the secret (if not already created)
./scripts/create-harbor-secrets.sh

# The Harbor HelmChart will automatically use the secret
# The secret must contain these keys:
#   - harborAdminPassword: Harbor admin password
#   - databasePassword: PostgreSQL database password
#   - redisPassword: Redis password (optional, can be empty)
```

**Alternative: Use Sealed Secrets** (Recommended for GitOps)
Install Sealed Secrets and create encrypted secrets that can be committed to Git:
```bash
# Install Sealed Secrets controller (if not already installed)
kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.0/controller.yaml

# Create a SealedSecret from the regular secret
kubectl create secret generic harbor-credentials \
  --from-literal=harborAdminPassword='<password>' \
  --from-literal=databasePassword='<password>' \
  -n managed-tools \
  --dry-run=client -o yaml | kubectl seal -o yaml > harbor/base/harbor-credentials-sealed.yaml
```

### Default Credentials (Development Only)

For initial setup, you can use these defaults (CHANGE IN PRODUCTION!):
- Harbor Admin Username: `admin`
- Harbor Admin Password: Set via secret
- Database Password: Set via secret

## Database Requirements

**⚠️ PostgreSQL Database Required**

Harbor requires a PostgreSQL database to be deployed separately. According to the [Harbor HA Helm documentation](https://goharbor.io/docs/1.10/install-config/harbor-ha-helm/), Harbor does not handle the deployment of the database for high availability scenarios.

### PostgreSQL Operator (Recommended)

A PostgreSQL operator is being set up to manage the database deployment. This is the recommended approach for production deployments.

**Once the PostgreSQL operator is deployed:**

1. Create a PostgreSQL instance using the operator
2. Note the service name and connection details
3. Update `harbor-helmchart.yaml` with the correct database connection:
   ```yaml
   database:
     type: external
     external:
       host: <postgresql-service-name>  # e.g., harbor-postgresql
       port: 5432
       username: <database-username>
       existingSecret: harbor-credentials
       secretKey: databasePassword
       database: registry
   ```

**Database Requirements:**
- PostgreSQL 9.6+ or 10+ (or as supported by the operator)
- Database named `registry` (or as configured)
- Database user with appropriate permissions
- Database password stored in `harbor-credentials` secret as `databasePassword`

### External PostgreSQL (Alternative)

If not using the PostgreSQL operator, you can use an external PostgreSQL service:

**Configuration:**
- Update `harbor-helmchart.yaml` with external database connection details:
  - `database.type: external`
  - `database.external.host`: PostgreSQL service hostname
  - `database.external.port`: PostgreSQL port (default: 5432)
  - `database.external.username`: Database username
  - `database.external.password`: Database password (or use `existingSecret`)
  - `database.external.database`: Database name (default: `registry`)

## Deployment

The Harbor HelmChart will be deployed automatically by Fleet when:
1. The namespace `managed-tools` exists
2. The TLS secret `wildcard-dataknife-net-tls` exists
3. **PostgreSQL database is deployed and accessible** (via operator or external service)
4. The credentials secret `harbor-credentials` exists with database connection details
5. Fleet syncs the GitRepo

Monitor deployment:
```bash
kubectl get helmchart -n managed-tools
kubectl get pods -n managed-tools
kubectl get ingress -n managed-tools
```
