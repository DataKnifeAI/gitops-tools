# Wazuh Secrets

This directory contains reference templates for Wazuh secrets.

## Files

- `wazuh-credentials.yaml.example` - Template for Wazuh credentials secret

## Usage

### Option 1: Using the Certificate Generation Script (Recommended)

The `generate-wazuh-certificates.sh` script automatically creates both:
- `wazuh-certs` secret (TLS certificates)
- `wazuh-credentials` secret (passwords)

```bash
# From repository root
./scripts/generate-wazuh-certificates.sh
```

This script:
- Generates TLS certificates for all Wazuh components
- Creates secure random passwords
- Creates both secrets in the `managed-tools` namespace

### Option 2: Using YAML file

1. Copy the example file:
   ```bash
   cp secrets/wazuh/wazuh-credentials.yaml.example secrets/wazuh/wazuh-credentials.yaml
   ```

2. Edit `secrets/wazuh/wazuh-credentials.yaml` with your actual passwords:
   ```bash
   nano secrets/wazuh/wazuh-credentials.yaml
   ```

3. Apply the secret:
   ```bash
   kubectl apply -f secrets/wazuh/wazuh-credentials.yaml
   ```

### Option 3: Using kubectl create

```bash
kubectl create secret generic wazuh-credentials \
  --from-literal=indexer-password='<secure-password>' \
  --from-literal=server-password='<secure-password>' \
  --from-literal=dashboard-password='<secure-password>' \
  -n managed-tools
```

## TLS Certificates

TLS certificates are created separately using the certificate generation script:

```bash
./scripts/generate-wazuh-certificates.sh
```

This creates the `wazuh-certs` secret with:
- `wazuh-indexer.pem` and `wazuh-indexer-key.pem`
- `wazuh-server.pem` and `wazuh-server-key.pem`
- `wazuh-dashboard.pem` and `wazuh-dashboard-key.pem`

## Important

- The `.env` file and `wazuh-credentials.yaml` (without .example) are gitignored
- Never commit actual passwords or certificates to git
- Change default passwords in production
- Consider using Sealed Secrets for GitOps workflows

## Sealed Secrets (Recommended for GitOps)

If using Sealed Secrets:

```bash
# Create a SealedSecret from the regular secret
kubectl create secret generic wazuh-credentials \
  --from-literal=indexer-password='<password>' \
  -n managed-tools \
  --dry-run=client -o yaml | kubectl seal -o yaml > secrets/wazuh/wazuh-credentials-sealed.yaml
```

Then commit `wazuh-credentials-sealed.yaml` to Git.
