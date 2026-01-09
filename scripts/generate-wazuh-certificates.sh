#!/bin/bash
# Generate Wazuh certificates for Kubernetes deployment
# Based on official Wazuh Kubernetes certificate generation script
# https://github.com/wazuh/wazuh-kubernetes

set -e

CERT_DIR="${CERT_DIR:-./certs/wazuh}"
NAMESPACE="${NAMESPACE:-managed-tools}"
WORK_DIR=$(mktemp -d)

# Cleanup function
cleanup() {
    rm -rf "${WORK_DIR}"
}
trap cleanup EXIT

echo "Generating Wazuh certificates for Kubernetes deployment..."
echo "Certificate directory: ${CERT_DIR}"
echo ""

# Create certs directory if it doesn't exist
mkdir -p "${CERT_DIR}"
cd "${WORK_DIR}"

# Generate Root CA
echo "Generating Root CA..."
openssl genrsa -out root-ca-key.pem 2048
openssl req -days 3650 -new -x509 -sha256 -key root-ca-key.pem -out root-ca.pem \
    -subj "/C=US/L=California/OU=Wazuh/O=Wazuh/CN=root-ca"

# Generate Admin certificate
echo "Generating Admin certificate..."
openssl genrsa -out admin-key-temp.pem 2048
openssl pkcs8 -inform PEM -outform PEM -in admin-key-temp.pem -topk8 -nocrypt \
    -v1 PBE-SHA1-3DES -out admin-key.pem
openssl req -days 3650 -new -key admin-key.pem -out admin.csr \
    -subj "/C=US/L=California/OU=Wazuh/O=Wazuh/CN=admin"
openssl x509 -req -days 3650 -in admin.csr -CA root-ca.pem -CAkey root-ca-key.pem \
    -CAcreateserial -sha256 -out admin.pem
rm -f admin-key-temp.pem admin.csr

# Generate Node (Indexer) certificate
echo "Generating Node (Indexer) certificate..."
openssl genrsa -out node-key-temp.pem 2048
openssl pkcs8 -inform PEM -outform PEM -in node-key-temp.pem -topk8 -nocrypt \
    -v1 PBE-SHA1-3DES -out node-key.pem
openssl req -days 3650 -new -key node-key.pem -out node.csr \
    -subj "/C=US/L=California/OU=Wazuh/O=Wazuh/CN=demo.indexer"
openssl x509 -req -days 3650 -in node.csr -CA root-ca.pem -CAkey root-ca-key.pem \
    -CAcreateserial -sha256 -out node.pem
rm -f node-key-temp.pem node.csr

# Generate Dashboard certificate
echo "Generating Dashboard certificate..."
openssl genrsa -out dashboard-key-temp.pem 2048
openssl pkcs8 -inform PEM -outform PEM -in dashboard-key-temp.pem -topk8 -nocrypt \
    -v1 PBE-SHA1-3DES -out dashboard-key.pem
openssl req -days 3650 -new -key dashboard-key.pem -out dashboard.csr \
    -subj "/C=US/L=California/OU=Wazuh/O=Wazuh/CN=dashboard"
openssl x509 -req -days 3650 -in dashboard.csr -CA root-ca.pem -CAkey root-ca-key.pem \
    -CAcreateserial -sha256 -out dashboard.pem
rm -f dashboard-key-temp.pem dashboard.csr root-ca-key.pem root-ca.srl

# Copy certificates to target directory
echo ""
echo "Copying certificates to ${CERT_DIR}..."
cp root-ca.pem "${CERT_DIR}/root-ca.pem"
cp admin.pem "${CERT_DIR}/admin.pem"
cp admin-key.pem "${CERT_DIR}/admin-key.pem"
cp node.pem "${CERT_DIR}/node.pem"
cp node-key.pem "${CERT_DIR}/node-key.pem"
cp dashboard.pem "${CERT_DIR}/dashboard.pem"
cp dashboard-key.pem "${CERT_DIR}/dashboard-key.pem"

echo "✓ All certificates generated successfully!"
echo ""

# Create namespace if it doesn't exist
echo "Creating namespace '${NAMESPACE}' if it doesn't exist..."
kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -

# Create Kubernetes secret with certificates
echo ""
echo "Creating Kubernetes secret 'wazuh-certs' in namespace '${NAMESPACE}'..."
kubectl create secret generic wazuh-certs \
    --from-file="${CERT_DIR}/root-ca.pem" \
    --from-file="${CERT_DIR}/admin.pem" \
    --from-file="${CERT_DIR}/admin-key.pem" \
    --from-file="${CERT_DIR}/node.pem" \
    --from-file="${CERT_DIR}/node-key.pem" \
    --from-file="${CERT_DIR}/dashboard.pem" \
    --from-file="${CERT_DIR}/dashboard-key.pem" \
    -n "${NAMESPACE}" \
    --dry-run=client -o yaml | kubectl apply -f -

echo "✓ Kubernetes secret 'wazuh-certs' created/updated in namespace '${NAMESPACE}'"
echo ""

# Generate random passwords for credentials
echo "Generating secure passwords for Wazuh credentials..."
INDEXER_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
SERVER_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
DASHBOARD_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)

echo ""
echo "⚠️  IMPORTANT: Save these passwords securely!"
echo ""
echo "Indexer Admin Password: ${INDEXER_PASSWORD}"
echo "Server Password:        ${SERVER_PASSWORD}"
echo "Dashboard Password:     ${DASHBOARD_PASSWORD}"
echo ""

# Create credentials secret
kubectl create secret generic wazuh-credentials \
    --from-literal=indexer-password="${INDEXER_PASSWORD}" \
    --from-literal=server-password="${SERVER_PASSWORD}" \
    --from-literal=dashboard-password="${DASHBOARD_PASSWORD}" \
    -n "${NAMESPACE}" \
    --dry-run=client -o yaml | kubectl apply -f -

echo ""
echo "✓ Kubernetes secret 'wazuh-credentials' created/updated in namespace '${NAMESPACE}'"
echo ""
echo "Certificate files saved to: ${CERT_DIR}"
echo ""
echo "Next steps:"
echo "1. Review the certificate files in ${CERT_DIR}"
echo "2. Ensure the secrets are created:"
echo "   kubectl get secrets -n ${NAMESPACE} | grep wazuh"
echo "3. Deploy Wazuh using Fleet GitOps"
echo ""
echo "⚠️  SECURITY NOTE:"
echo "   - Certificate files in ${CERT_DIR} contain sensitive data"
echo "   - Do NOT commit these files to Git"
echo "   - The ${CERT_DIR} directory should be in .gitignore"
echo "   - Passwords are stored in Kubernetes secrets (consider using Sealed Secrets for GitOps)"
echo ""
