#!/bin/bash
# Update Harbor HelmChart with passwords from secret or .env file
# This script extracts passwords from the secret and updates the HelmChartConfig

set -e

# Load .env file if it exists
if [ -f .env ]; then
    echo "Loading credentials from .env file..."
    export $(grep -v '^#' .env | xargs)
fi

NAMESPACE="${HARBOR_NAMESPACE:-${NAMESPACE:-managed-tools}}"
SECRET_NAME="harbor-credentials"
HELMCHARTCONFIG="harbor/base/harbor-helmchartconfig.yaml"

echo "Updating Harbor passwords..."

# Try to get passwords from .env first, then from secret
if [ -n "${HARBOR_ADMIN_PASSWORD}" ] && [ -n "${HARBOR_DATABASE_PASSWORD}" ]; then
    echo "Using passwords from .env file..."
    HARBOR_PASSWORD="${HARBOR_ADMIN_PASSWORD}"
    DB_PASSWORD="${HARBOR_DATABASE_PASSWORD}"
elif kubectl get secret "${SECRET_NAME}" -n "${NAMESPACE}" >/dev/null 2>&1; then
    echo "Extracting passwords from secret..."
    HARBOR_PASSWORD=$(kubectl get secret "${SECRET_NAME}" -n "${NAMESPACE}" -o jsonpath='{.data.harborAdminPassword}' | base64 -d)
    DB_PASSWORD=$(kubectl get secret "${SECRET_NAME}" -n "${NAMESPACE}" -o jsonpath='{.data.databasePassword}' | base64 -d)
else
    echo "Error: No .env file found and secret '${SECRET_NAME}' not found in namespace '${NAMESPACE}'"
    echo "Please either:"
    echo "  1. Create .env file: ./scripts/create-env-file.sh"
    echo "  2. Or create secret: ./scripts/create-harbor-secrets.sh"
    exit 1
fi

# Update HelmChartConfig (this is a manual step - you'll need to apply it)
echo ""
echo "Passwords extracted from secret. Update ${HELMCHARTCONFIG} with:"
echo ""
echo "  harborAdminPassword: \"${HARBOR_PASSWORD}\""
echo "  database:"
echo "    internal:"
echo "      password: \"${DB_PASSWORD}\""
echo ""
echo "⚠️  Note: For security, consider using Sealed Secrets or External Secrets Operator"
echo "   to encrypt secrets in Git instead of storing them in plain HelmChartConfig"
echo ""
