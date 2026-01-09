#!/bin/bash
# Configure DockerHub proxy cache for a Harbor project
# This script attempts to enable proxy cache via API, but may require manual UI configuration
#
# Usage:
#   ./scripts/configure-dockerhub-proxy.sh

set -e

# Load .env file if it exists
if [ -f .env ]; then
    echo "Loading configuration from .env file..."
    export $(grep -v '^#' .env | xargs)
fi

# Configuration
HARBOR_URL="${HARBOR_REGISTRY_URL:-harbor.dataknife.net}"
HARBOR_ADMIN_USER="${HARBOR_ADMIN_USER:-admin}"
HARBOR_ADMIN_PASSWORD="${HARBOR_ADMIN_PASSWORD:-Harbor12345}"
PROJECT_NAME="${DOCKERHUB_PROJECT:-dockerhub}"

HARBOR_API="https://${HARBOR_URL}/api/v2.0"

echo "Configuring DockerHub proxy cache for project '${PROJECT_NAME}'..."
echo ""

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo "Error: jq is required but not installed. Install with: sudo apt install jq"
    exit 1
fi

# Get project ID
PROJECT_ID=$(curl -s -k -u "${HARBOR_ADMIN_USER}:${HARBOR_ADMIN_PASSWORD}" \
  "${HARBOR_API}/projects?name=${PROJECT_NAME}" \
  | jq -r ".[] | select(.name == \"${PROJECT_NAME}\") | .project_id // empty")

if [ -z "$PROJECT_ID" ]; then
    echo "Error: Project '${PROJECT_NAME}' not found"
    exit 1
fi

# Get registry ID
REGISTRY_ID=$(curl -s -k -u "${HARBOR_ADMIN_USER}:${HARBOR_ADMIN_PASSWORD}" \
  "${HARBOR_API}/registries" \
  | jq -r ".[] | select(.name == \"DockerHub\") | .id // empty")

if [ -z "$REGISTRY_ID" ]; then
    echo "Error: DockerHub registry endpoint not found"
    exit 1
fi

echo "Project ID: ${PROJECT_ID}"
echo "Registry ID: ${REGISTRY_ID}"
echo ""

# Try updating project with registry_id in metadata
echo "Attempting to configure proxy cache via API..."
PROJECT_UPDATE=$(curl -s -k -u "${HARBOR_ADMIN_USER}:${HARBOR_ADMIN_PASSWORD}" \
  -X PUT "${HARBOR_API}/projects/${PROJECT_ID}" \
  -H "Content-Type: application/json" \
  -d "{
    \"registry_id\": ${REGISTRY_ID}
  }")

# Check if it worked
sleep 2
CURRENT_REGISTRY_ID=$(curl -s -k -u "${HARBOR_ADMIN_USER}:${HARBOR_ADMIN_PASSWORD}" \
  "${HARBOR_API}/projects/${PROJECT_ID}" \
  | jq -r '.registry_id // "null"')

if [ "$CURRENT_REGISTRY_ID" = "$REGISTRY_ID" ]; then
    echo "✓ Proxy cache configured successfully via API"
else
    echo "⚠️  API configuration may not have worked"
    echo ""
    echo "Please configure proxy cache manually via Harbor UI:"
    echo "  1. Go to: https://${HARBOR_URL}/harbor/projects/${PROJECT_NAME}"
    echo "  2. Click 'Configuration' tab"
    echo "  3. Set 'Proxy Cache' to 'DockerHub' registry"
    echo "  4. Click 'Save'"
    echo ""
    echo "Current registry_id: ${CURRENT_REGISTRY_ID}"
    echo "Expected registry_id: ${REGISTRY_ID}"
fi

