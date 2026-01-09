#!/bin/bash
# Create a Harbor proxy cache project with DockerHub registry
# This script creates a project with proxy cache enabled from the start
# According to Harbor docs, proxy cache can only be enabled when creating a project
#
# Usage:
#   ./scripts/create-proxy-cache-project.sh
#   HARBOR_URL=harbor.dataknife.net PROJECT_NAME=dockerhub ./scripts/create-proxy-cache-project.sh

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
REGISTRY_NAME="${DOCKERHUB_REGISTRY_NAME:-DockerHub}"

HARBOR_API="https://${HARBOR_URL}/api/v2.0"

echo "Creating Harbor proxy cache project..."
echo ""
echo "Configuration:"
echo "  Harbor URL: ${HARBOR_URL}"
echo "  Project Name: ${PROJECT_NAME}"
echo "  Registry Name: ${REGISTRY_NAME}"
echo ""

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo "Error: jq is required but not installed. Install with: sudo apt install jq"
    exit 1
fi

# Authenticate using basic auth
echo "Authenticating as admin..."
AUTH_TEST=$(curl -s -k -u "${HARBOR_ADMIN_USER}:${HARBOR_ADMIN_PASSWORD}" \
  "${HARBOR_API}/users/current" | jq -r '.username // empty')

if [ -z "$AUTH_TEST" ] || [ "$AUTH_TEST" != "admin" ]; then
    echo "Error: Failed to authenticate. Check your Harbor admin credentials."
    exit 1
fi
echo "✓ Authenticated"
echo ""

# Check if registry endpoint exists
echo "Step 1: Checking registry endpoint '${REGISTRY_NAME}'..."
REGISTRY_ID=$(curl -s -k -u "${HARBOR_ADMIN_USER}:${HARBOR_ADMIN_PASSWORD}" \
  -X GET "${HARBOR_API}/registries" \
  | jq -r ".[] | select(.name == \"${REGISTRY_NAME}\") | .id // empty")

if [ -z "$REGISTRY_ID" ]; then
    echo "Error: Registry endpoint '${REGISTRY_NAME}' not found."
    echo "Please create the registry endpoint first using:"
    echo "  ./scripts/create-harbor-dockerhub-mirror.sh"
    exit 1
fi
echo "✓ Registry endpoint found (ID: ${REGISTRY_ID})"
echo ""

# Check if project already exists
echo "Step 2: Checking if project '${PROJECT_NAME}' exists..."
EXISTING_PROJECT=$(curl -s -k -u "${HARBOR_ADMIN_USER}:${HARBOR_ADMIN_PASSWORD}" \
  -X GET "${HARBOR_API}/projects?name=${PROJECT_NAME}" \
  | jq -r ".[] | select(.name == \"${PROJECT_NAME}\") | .project_id // empty")

if [ -n "$EXISTING_PROJECT" ]; then
    EXISTING_REGISTRY_ID=$(curl -s -k -u "${HARBOR_ADMIN_USER}:${HARBOR_ADMIN_PASSWORD}" \
      -X GET "${HARBOR_API}/projects/${EXISTING_PROJECT}" \
      | jq -r '.registry_id // "null"')
    
    if [ "$EXISTING_REGISTRY_ID" = "$REGISTRY_ID" ]; then
        echo "✓ Project '${PROJECT_NAME}' already exists with proxy cache enabled (Registry ID: ${REGISTRY_ID})"
        exit 0
    else
        echo "⚠️  Project '${PROJECT_NAME}' exists but proxy cache is not configured correctly"
        echo "   Current registry_id: ${EXISTING_REGISTRY_ID}"
        echo "   Required registry_id: ${REGISTRY_ID}"
        echo ""
        echo "According to Harbor documentation, proxy cache can only be enabled when creating a project."
        echo "You need to delete the existing project and recreate it with proxy cache enabled."
        echo ""
        read -p "Delete and recreate project '${PROJECT_NAME}'? (yes/no): " -r
        if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
            echo "Aborted."
            exit 1
        fi
        
        echo "Deleting existing project..."
        curl -s -k -u "${HARBOR_ADMIN_USER}:${HARBOR_ADMIN_PASSWORD}" \
          -X DELETE "${HARBOR_API}/projects/${EXISTING_PROJECT}" > /dev/null
        echo "✓ Project deleted"
        sleep 2
    fi
fi

# Create project with proxy cache enabled
echo "Step 3: Creating proxy cache project '${PROJECT_NAME}'..."
PROJECT_RESPONSE=$(curl -s -k -u "${HARBOR_ADMIN_USER}:${HARBOR_ADMIN_PASSWORD}" \
  -X POST "${HARBOR_API}/projects" \
  -H "Content-Type: application/json" \
  -d "{
    \"project_name\": \"${PROJECT_NAME}\",
    \"public\": true,
    \"registry_id\": ${REGISTRY_ID},
    \"metadata\": {
      \"public\": \"true\",
      \"enable_content_trust\": \"false\",
      \"prevent_vulnerable_images_from_running\": \"false\",
      \"prevent_vulnerable_images_from_running_severity\": \"\",
      \"automatically_scan_images_on_push\": \"false\"
    }
  }")

# Check for errors
if echo "$PROJECT_RESPONSE" | jq -e '.errors' >/dev/null 2>&1; then
    ERROR_CODE=$(echo "$PROJECT_RESPONSE" | jq -r '.errors[0].code // "UNKNOWN"')
    if [ "$ERROR_CODE" = "CONFLICT" ]; then
        echo "Project '${PROJECT_NAME}' already exists (may have been created by another process)"
    else
        echo "Error: Failed to create project '${PROJECT_NAME}'"
        echo "Response: $PROJECT_RESPONSE"
        exit 1
    fi
fi

# Verify proxy cache is enabled
sleep 2
CREATED_PROJECT=$(curl -s -k -u "${HARBOR_ADMIN_USER}:${HARBOR_ADMIN_PASSWORD}" \
  -X GET "${HARBOR_API}/projects?name=${PROJECT_NAME}" \
  | jq -r ".[] | select(.name == \"${PROJECT_NAME}\")")

PROJECT_REGISTRY_ID=$(echo "$CREATED_PROJECT" | jq -r '.registry_id // "null"')

if [ "$PROJECT_REGISTRY_ID" = "$REGISTRY_ID" ]; then
    echo "✓ Proxy cache project '${PROJECT_NAME}' created successfully"
    echo "✓ Proxy cache enabled with registry ID: ${REGISTRY_ID} (${REGISTRY_NAME})"
else
    echo "⚠️  Project created but proxy cache may not be enabled correctly"
    echo "   Registry ID: ${PROJECT_REGISTRY_ID}"
    echo "   Expected: ${REGISTRY_ID}"
fi
echo ""

echo "Proxy cache project setup complete!"
echo ""
echo "Usage:"
echo "  # Pull an image through the proxy cache"
echo "  docker pull ${HARBOR_URL}/${PROJECT_NAME}/library/nginx:latest"
echo ""
echo "  # For official images, include 'library' namespace"
echo "  docker pull ${HARBOR_URL}/${PROJECT_NAME}/library/hello-world:latest"
echo ""
echo "Note: Images are cached on-demand when you pull them."
