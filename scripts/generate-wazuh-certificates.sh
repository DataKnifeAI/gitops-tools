#!/bin/bash
# Generate Wazuh certificates for Kubernetes deployment
# This script downloads the Wazuh installation assistant and generates certificates
# for Wazuh Indexer, Server, and Dashboard components

set -e

CERT_DIR="${CERT_DIR:-./certs/wazuh}"
NAMESPACE="${NAMESPACE:-managed-tools}"
WAZUH_VERSION="${WAZUH_VERSION:-4.14}"
INSTALL_SCRIPT="wazuh-install.sh"
TEMP_DIR=$(mktemp -d)

# Cleanup function
cleanup() {
    rm -rf "${TEMP_DIR}"
}
trap cleanup EXIT

echo "Generating Wazuh certificates for Kubernetes deployment..."
echo "Wazuh Version: ${WAZUH_VERSION}"
echo ""

# Create certs directory if it doesn't exist
mkdir -p "${CERT_DIR}"

# Download Wazuh installation assistant
echo "Downloading Wazuh installation assistant..."
cd "${TEMP_DIR}"
curl -sO "https://packages.wazuh.com/${WAZUH_VERSION}/${INSTALL_SCRIPT}"
chmod 744 "${INSTALL_SCRIPT}"

# Generate certificates only (without installing)
echo "Generating certificates..."
./${INSTALL_SCRIPT} -g

# Check if certificate files were generated
if [ ! -f "wazuh-install-files.tar" ]; then
    echo "Error: Certificate generation failed. wazuh-install-files.tar not found."
    exit 1
fi

# Extract certificate files
echo "Extracting certificate files..."
tar -xf wazuh-install-files.tar

# Find certificate files
CERT_FILES=(
    "wazuh-indexer/wazuh-indexer.pem"
    "wazuh-indexer/wazuh-indexer-key.pem"
    "wazuh-manager/wazuh-server.pem"
    "wazuh-manager/wazuh-server-key.pem"
    "wazuh-dashboard/wazuh-dashboard.pem"
    "wazuh-dashboard/wazuh-dashboard-key.pem"
)

# Copy certificates to certs directory
echo "Copying certificates to ${CERT_DIR}..."
for cert_file in "${CERT_FILES[@]}"; do
    if [ -f "${cert_file}" ]; then
        filename=$(basename "${cert_file}")
        cp "${cert_file}" "${CERT_DIR}/${filename}"
        echo "  ✓ Copied ${filename}"
    else
        echo "  ⚠ Warning: ${cert_file} not found"
    fi
done

# Create namespace if it doesn't exist
echo ""
echo "Creating namespace '${NAMESPACE}' if it doesn't exist..."
kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -

# Create Kubernetes secret with certificates
echo "Creating Kubernetes secret 'wazuh-certs' in namespace '${NAMESPACE}'..."

# Check if all required certificate files exist
REQUIRED_CERTS=(
    "${CERT_DIR}/wazuh-indexer.pem"
    "${CERT_DIR}/wazuh-indexer-key.pem"
    "${CERT_DIR}/wazuh-server.pem"
    "${CERT_DIR}/wazuh-server-key.pem"
    "${CERT_DIR}/wazuh-dashboard.pem"
    "${CERT_DIR}/wazuh-dashboard-key.pem"
)

MISSING_CERTS=()
for cert in "${REQUIRED_CERTS[@]}"; do
    if [ ! -f "${cert}" ]; then
        MISSING_CERTS+=("${cert}")
    fi
done

if [ ${#MISSING_CERTS[@]} -gt 0 ]; then
    echo "Error: Missing required certificate files:"
    for cert in "${MISSING_CERTS[@]}"; do
        echo "  - ${cert}"
    done
    echo ""
    echo "Please check the extracted files and ensure all certificates were generated."
    exit 1
fi

# Create the secret
kubectl create secret generic wazuh-certs \
    --from-file="${CERT_DIR}/wazuh-indexer.pem" \
    --from-file="${CERT_DIR}/wazuh-indexer-key.pem" \
    --from-file="${CERT_DIR}/wazuh-server.pem" \
    --from-file="${CERT_DIR}/wazuh-server-key.pem" \
    --from-file="${CERT_DIR}/wazuh-dashboard.pem" \
    --from-file="${CERT_DIR}/wazuh-dashboard-key.pem" \
    -n "${NAMESPACE}" \
    --dry-run=client -o yaml | kubectl apply -f -

echo ""
echo "✓ Kubernetes secret 'wazuh-certs' created/updated in namespace '${NAMESPACE}'"
echo ""

# Generate random passwords for credentials
echo "Generating secure passwords for Wazuh credentials..."
INDEXER_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
SERVER_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
DASHBOARD_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)

echo ""
echo "Creating Wazuh credentials secret..."
echo "⚠️  IMPORTANT: Save these passwords securely!"
echo ""
echo "Indexer Password:   ${INDEXER_PASSWORD}"
echo "Server Password:    ${SERVER_PASSWORD}"
echo "Dashboard Password: ${DASHBOARD_PASSWORD}"
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
echo "3. Update Wazuh manifests to reference these secrets"
echo "4. Deploy Wazuh using Fleet GitOps"
echo ""
echo "⚠️  SECURITY NOTE:"
echo "   - Certificate files in ${CERT_DIR} contain sensitive data"
echo "   - Do NOT commit these files to Git"
echo "   - The ${CERT_DIR} directory should be in .gitignore"
echo "   - Passwords are stored in Kubernetes secrets (consider using Sealed Secrets for GitOps)"
echo ""
