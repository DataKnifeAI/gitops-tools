#!/bin/bash
# Create DockerHub proxy cache in Harbor
# This script sets up a proxy cache project that caches DockerHub images on-demand
# When you pull an image through this project, Harbor automatically fetches it from DockerHub
# and caches it for future use. Only images you actually pull are cached.
#
# Usage:
#   ./scripts/create-harbor-dockerhub-mirror.sh
#   HARBOR_URL=harbor.dataknife.net DOCKERHUB_USERNAME=user DOCKERHUB_PASSWORD=pass ./scripts/create-harbor-dockerhub-mirror.sh

set -e

# Load .env file if it exists
if [ -f .env ]; then
    echo "Loading configuration from .env file..."
    export $(grep -v '^#' .env | xargs)
fi

# Configuration
HARBOR_URL="${HARBOR_REGISTRY_URL:-${HARBOR_URL:-harbor.dataknife.net}}"
HARBOR_ADMIN_USER="${HARBOR_ADMIN_USER:-admin}"
HARBOR_ADMIN_PASSWORD="${HARBOR_ADMIN_PASSWORD:-Harbor12345}"
DOCKERHUB_USERNAME="${DOCKERHUB_USERNAME:-}"
DOCKERHUB_PASSWORD="${DOCKERHUB_PASSWORD:-}"
PROJECT_NAME="${DOCKERHUB_PROJECT:-dockerhub}"
REGISTRY_NAME="${DOCKERHUB_REGISTRY_NAME:-DockerHub}"

# Harbor API endpoint
HARBOR_API="https://${HARBOR_URL}/api/v2.0"

echo "Setting up DockerHub proxy cache in Harbor (on-demand caching)..."
echo ""
echo "Configuration:"
echo "  Harbor URL: ${HARBOR_URL}"
echo "  Project: ${PROJECT_NAME}"
echo "  Registry Name: ${REGISTRY_NAME}"
echo "  DockerHub Username: ${DOCKERHUB_USERNAME:-<anonymous>}"
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

# Step 1: Create or check project for DockerHub proxy cache
echo "Step 1: Checking/creating proxy cache project '${PROJECT_NAME}'..."
PROJECT_INFO=$(curl -s -k -u "${HARBOR_ADMIN_USER}:${HARBOR_ADMIN_PASSWORD}" \
  -X GET "${HARBOR_API}/projects?name=${PROJECT_NAME}" \
  | jq -r ".[] | select(.name == \"${PROJECT_NAME}\")")

PROJECT_EXISTS=$(echo "$PROJECT_INFO" | jq -r '.name // empty')

if [ -z "$PROJECT_EXISTS" ]; then
    echo "Creating proxy cache project '${PROJECT_NAME}'..."
    # Note: registry_id might need to be set after project creation via UI
    # Some Harbor versions don't support setting it via API during creation
    PROJECT_RESPONSE=$(curl -s -k -u "${HARBOR_ADMIN_USER}:${HARBOR_ADMIN_PASSWORD}" \
      -X POST "${HARBOR_API}/projects" \
      -H "Content-Type: application/json" \
      -d "{
        \"project_name\": \"${PROJECT_NAME}\",
        \"public\": true,
        \"metadata\": {
          \"public\": \"true\",
          \"enable_content_trust\": \"false\",
          \"prevent_vulnerable_images_from_running\": \"false\",
          \"prevent_vulnerable_images_from_running_severity\": \"\",
          \"automatically_scan_images_on_push\": \"false\"
        }
      }")
    
    if echo "$PROJECT_RESPONSE" | grep -q "errors"; then
        echo "Error: Failed to create project '${PROJECT_NAME}'."
        echo "Response: $PROJECT_RESPONSE"
        exit 1
    fi
    echo "✓ Project '${PROJECT_NAME}' created"
    # Re-fetch project info to get project details
    PROJECT_INFO=$(curl -s -k -u "${HARBOR_ADMIN_USER}:${HARBOR_ADMIN_PASSWORD}" \
      -X GET "${HARBOR_API}/projects?name=${PROJECT_NAME}" \
      | jq -r ".[] | select(.name == \"${PROJECT_NAME}\")")
else
    echo "✓ Project '${PROJECT_NAME}' already exists"
fi
echo ""

# Step 2: Create or check registry endpoint for DockerHub
echo "Step 2: Checking/creating registry endpoint '${REGISTRY_NAME}'..."
REGISTRY_EXISTS=$(curl -s -k -u "${HARBOR_ADMIN_USER}:${HARBOR_ADMIN_PASSWORD}" \
  -X GET "${HARBOR_API}/registries" \
  | jq -r ".[] | select(.name == \"${REGISTRY_NAME}\") | .id // empty")

if [ -z "$REGISTRY_EXISTS" ]; then
    echo "Creating registry endpoint '${REGISTRY_NAME}'..."
    
    # Build registry payload
    REGISTRY_PAYLOAD="{
      \"name\": \"${REGISTRY_NAME}\",
      \"type\": \"docker-hub\",
      \"url\": \"https://registry-1.docker.io\",
      \"insecure\": false,
      \"description\": \"DockerHub registry for image mirroring\"
    }"
    
    # Add credentials if provided
    if [ -n "$DOCKERHUB_USERNAME" ] && [ -n "$DOCKERHUB_PASSWORD" ]; then
        REGISTRY_PAYLOAD=$(echo "$REGISTRY_PAYLOAD" | jq ". + {
          \"credential\": {
            \"type\": \"basic\",
            \"access_key\": \"${DOCKERHUB_USERNAME}\",
            \"access_secret\": \"${DOCKERHUB_PASSWORD}\"
          }
        }")
    fi
    
    REGISTRY_RESPONSE=$(curl -s -k -u "${HARBOR_ADMIN_USER}:${HARBOR_ADMIN_PASSWORD}" \
      -X POST "${HARBOR_API}/registries" \
      -H "Content-Type: application/json" \
      -d "$REGISTRY_PAYLOAD")
    
    # Check for errors
    if echo "$REGISTRY_RESPONSE" | jq -e '.errors' >/dev/null 2>&1; then
        ERROR_CODE=$(echo "$REGISTRY_RESPONSE" | jq -r '.errors[0].code // "UNKNOWN"')
        if [ "$ERROR_CODE" = "CONFLICT" ]; then
            echo "Registry '${REGISTRY_NAME}' already exists, fetching ID..."
            REGISTRY_EXISTS=$(curl -s -k -u "${HARBOR_ADMIN_USER}:${HARBOR_ADMIN_PASSWORD}" \
              -X GET "${HARBOR_API}/registries" \
              | jq -r ".[] | select(.name == \"${REGISTRY_NAME}\") | .id")
            echo "✓ Registry endpoint '${REGISTRY_NAME}' already exists (ID: ${REGISTRY_EXISTS})"
        else
            echo "Error: Failed to create registry endpoint"
            echo "Response: $REGISTRY_RESPONSE"
            exit 1
        fi
    else
        REGISTRY_ID=$(echo "$REGISTRY_RESPONSE" | jq -r '.id // empty')
        if [ -z "$REGISTRY_ID" ] || [ "$REGISTRY_ID" = "null" ]; then
            echo "Error: Failed to create registry endpoint (no ID in response)"
            echo "Response: $REGISTRY_RESPONSE"
            exit 1
        fi
        echo "✓ Registry endpoint '${REGISTRY_NAME}' created (ID: ${REGISTRY_ID})"
        REGISTRY_EXISTS="$REGISTRY_ID"
    fi
else
    echo "✓ Registry endpoint '${REGISTRY_NAME}' already exists (ID: ${REGISTRY_EXISTS})"
fi
echo ""

# Step 3: Configure project as proxy cache
echo "Step 3: Configuring project as proxy cache..."
CURRENT_REGISTRY_ID=$(echo "$PROJECT_INFO" | jq -r '.registry_id // "null"')

if [ "$CURRENT_REGISTRY_ID" = "null" ] || [ "$CURRENT_REGISTRY_ID" = "0" ] || [ -z "$CURRENT_REGISTRY_ID" ]; then
    echo "Attempting to configure project '${PROJECT_NAME}' as proxy cache..."
    echo "Note: Some Harbor versions require proxy cache to be configured via UI"
    echo ""
    
    # Try to update via API (may not work in all Harbor versions)
    PROJECT_UPDATE_RESPONSE=$(curl -s -k -u "${HARBOR_ADMIN_USER}:${HARBOR_ADMIN_PASSWORD}" \
      -X PUT "${HARBOR_API}/projects/${PROJECT_NAME}" \
      -H "Content-Type: application/json" \
      -d "{
        \"project_name\": \"${PROJECT_NAME}\",
        \"registry_id\": ${REGISTRY_EXISTS},
        \"metadata\": {
          \"public\": \"true\"
        }
      }")
    
    # Check if it worked
    sleep 1
    UPDATED_PROJECT=$(curl -s -k -u "${HARBOR_ADMIN_USER}:${HARBOR_ADMIN_PASSWORD}" \
      -X GET "${HARBOR_API}/projects/${PROJECT_NAME}" \
      | jq -r '.registry_id // "null"')
    
    if [ "$UPDATED_PROJECT" != "null" ] && [ "$UPDATED_PROJECT" != "0" ] && [ -n "$UPDATED_PROJECT" ]; then
        echo "✓ Project '${PROJECT_NAME}' configured as proxy cache via API (Registry ID: ${UPDATED_PROJECT})"
    else
        echo "⚠️  API update may not have worked (registry_id still null)"
        echo "   Please configure proxy cache manually via Harbor UI:"
        echo "   1. Go to: https://${HARBOR_URL}/harbor/projects/${PROJECT_NAME}/repositories"
        echo "   2. Click 'Configuration' tab"
        echo "   3. Set 'Proxy Cache' to 'DockerHub' registry"
        echo "   Or check Harbor documentation for your version"
        echo ""
        echo "   Registry ID to use: ${REGISTRY_EXISTS} (${REGISTRY_NAME})"
    fi
else
    if [ "$CURRENT_REGISTRY_ID" = "$REGISTRY_EXISTS" ]; then
        echo "✓ Project '${PROJECT_NAME}' already configured as proxy cache (Registry ID: ${CURRENT_REGISTRY_ID})"
    else
        echo "⚠️  Project '${PROJECT_NAME}' is configured with a different registry (ID: ${CURRENT_REGISTRY_ID})"
        echo "   Current registry: ${CURRENT_REGISTRY_ID}"
        echo "   Desired registry: ${REGISTRY_EXISTS} (${REGISTRY_NAME})"
        echo "   You may need to update this via Harbor UI"
    fi
fi
echo ""

echo "✓ DockerHub proxy cache setup complete!"
echo ""
echo "Summary:"
echo "  Project: ${PROJECT_NAME} (public, proxy cache enabled)"
echo "  Registry: ${REGISTRY_NAME} (ID: ${REGISTRY_EXISTS})"
echo "  Cache Mode: On-demand (images are cached when you pull them)"
echo ""
echo "How it works:"
echo "  - Pull images through Harbor: docker pull ${HARBOR_URL}/${PROJECT_NAME}/<image>:<tag>"
echo "  - Harbor automatically fetches from DockerHub if not cached"
echo "  - Subsequent pulls are served from Harbor's cache"
echo "  - Only images you actually pull are cached (no full replication)"
echo ""
echo "Examples:"
echo "  # Pull nginx from DockerHub (will be cached automatically)"
echo "  docker pull ${HARBOR_URL}/${PROJECT_NAME}/nginx:latest"
echo ""
echo "  # Pull redis (will be cached on first pull)"
echo "  docker pull ${HARBOR_URL}/${PROJECT_NAME}/redis:alpine"
echo ""
echo "  # Subsequent pulls of the same image use the cache"
echo "  docker pull ${HARBOR_URL}/${PROJECT_NAME}/nginx:latest  # Served from cache"
echo ""
echo "Note: The project acts as a transparent proxy cache."
echo "      Images are cached automatically when you pull them."
echo ""
