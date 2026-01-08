#!/bin/bash
# Install Harbor wildcard certificate from Kubernetes to Docker
# This script extracts the certificate from the Kubernetes secret and installs it
# so Docker can verify Harbor's TLS certificate
#
# Usage:
#   ./scripts/install-harbor-cert.sh

set -e

NAMESPACE="${HARBOR_NAMESPACE:-managed-tools}"
SECRET_NAME="${HARBOR_TLS_SECRET:-wildcard-dataknife-net-tls}"
HARBOR_URL="${HARBOR_REGISTRY_URL:-harbor.dataknife.net}"

echo "=========================================="
echo "Harbor Certificate Installation"
echo "=========================================="
echo ""
echo "Configuration:"
echo "  Namespace: ${NAMESPACE}"
echo "  Secret: ${SECRET_NAME}"
echo "  Harbor URL: ${HARBOR_URL}"
echo ""

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo "Error: kubectl is not installed or not in PATH"
    exit 1
fi

# Check if secret exists
if ! kubectl get secret "${SECRET_NAME}" -n "${NAMESPACE}" > /dev/null 2>&1; then
    echo "Error: Secret '${SECRET_NAME}' not found in namespace '${NAMESPACE}'"
    exit 1
fi

echo "✓ Secret found in Kubernetes"
echo ""

# Extract certificate
echo "Extracting certificate from Kubernetes secret..."
TEMP_CERT=$(mktemp)
kubectl get secret "${SECRET_NAME}" -n "${NAMESPACE}" -o jsonpath='{.data.tls\.crt}' | base64 -d > "${TEMP_CERT}"

if [ ! -s "${TEMP_CERT}" ]; then
    echo "Error: Failed to extract certificate"
    rm -f "${TEMP_CERT}"
    exit 1
fi

echo "✓ Certificate extracted"
echo ""

# Install certificate to Docker
CERT_DIR="/etc/docker/certs.d/${HARBOR_URL}"
CERT_FILE="${CERT_DIR}/ca.crt"

echo "Installing certificate to Docker..."
echo "  Directory: ${CERT_DIR}"
echo "  File: ${CERT_FILE}"
echo ""
echo "This requires sudo privileges..."

sudo mkdir -p "${CERT_DIR}"
sudo cp "${TEMP_CERT}" "${CERT_FILE}"
sudo chmod 644 "${CERT_FILE}"

rm -f "${TEMP_CERT}"

echo "✓ Certificate installed to ${CERT_FILE}"
echo ""

# Restart Docker
echo "Restarting Docker daemon..."
sudo systemctl restart docker
sleep 3

if docker info > /dev/null 2>&1; then
    echo "✓ Docker restarted successfully"
else
    echo "⚠️  Docker may need a moment to start"
fi
echo ""

# Verify certificate
echo "Verifying certificate installation..."
if [ -f "${CERT_FILE}" ]; then
    CERT_SUBJECT=$(openssl x509 -in "${CERT_FILE}" -noout -subject 2>/dev/null | sed 's/subject=//' || echo "unknown")
    echo "✓ Certificate file exists"
    echo "  Subject: ${CERT_SUBJECT}"
else
    echo "✗ Certificate file not found"
    exit 1
fi
echo ""

echo "=========================================="
echo "Certificate Installation Complete"
echo "=========================================="
echo ""
echo "You can now use Docker with Harbor:"
echo "  docker login ${HARBOR_URL} -u <username> -p <password>"
echo ""
echo "To test, run:"
echo "  ./scripts/test-harbor-push-pull.sh"
echo ""
