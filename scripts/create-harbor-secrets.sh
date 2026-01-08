#!/bin/bash
# Create Harbor credentials secret
# This script reads from .env file or prompts for passwords

set -e

# Load .env file from project root if it exists
if [ -f .env ]; then
    echo "Loading credentials from .env file..."
    export $(grep -v '^#' .env | xargs)
fi

NAMESPACE="${HARBOR_NAMESPACE:-${NAMESPACE:-managed-tools}}"
SECRET_NAME="harbor-credentials"

echo "Creating Harbor credentials secret..."
echo ""

# Create namespace if it doesn't exist
kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -

# Get Harbor admin password from env or prompt
if [ -z "${HARBOR_ADMIN_PASSWORD}" ]; then
    read -sp "Enter Harbor admin password (default: Harbor12345): " HARBOR_PASSWORD
    HARBOR_PASSWORD="${HARBOR_PASSWORD:-Harbor12345}"
else
    HARBOR_PASSWORD="${HARBOR_ADMIN_PASSWORD}"
    echo "Using Harbor admin password from .env"
fi
echo ""

# Get database password from env or prompt
if [ -z "${HARBOR_DATABASE_PASSWORD}" ]; then
    read -sp "Enter database password (default: root123): " DB_PASSWORD
    DB_PASSWORD="${DB_PASSWORD:-root123}"
else
    DB_PASSWORD="${HARBOR_DATABASE_PASSWORD}"
    echo "Using database password from .env"
fi
echo ""

# Get Redis password from env or prompt
if [ -z "${HARBOR_REDIS_PASSWORD}" ]; then
    read -sp "Enter Redis password (optional, press Enter for empty): " REDIS_PASSWORD
    REDIS_PASSWORD="${REDIS_PASSWORD:-}"
else
    REDIS_PASSWORD="${HARBOR_REDIS_PASSWORD}"
    echo "Using Redis password from .env"
fi
echo ""

# Create the secret
kubectl create secret generic "${SECRET_NAME}" \
  --from-literal=harborAdminPassword="${HARBOR_PASSWORD}" \
  --from-literal=databasePassword="${DB_PASSWORD}" \
  --from-literal=redisPassword="${REDIS_PASSWORD}" \
  -n "${NAMESPACE}" \
  --dry-run=client -o yaml | kubectl apply -f -

echo ""
echo "✓ Harbor credentials secret '${SECRET_NAME}' created/updated in namespace '${NAMESPACE}'"
echo ""
echo "⚠️  Remember to change these passwords in production!"
