#!/bin/bash
# Create Harbor robot account for CI/CD builds
# This script creates a robot account in Harbor via API
#
# Usage:
#   ./scripts/create-harbor-robot-account.sh
#   HARBOR_URL=harbor.dataknife.net HARBOR_ROBOT_NAME=ci-builder ./scripts/create-harbor-robot-account.sh

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
ROBOT_NAME="${HARBOR_ROBOT_ACCOUNT_NAME:-${ROBOT_NAME:-ci-builder}}"
PROJECT="${HARBOR_PROJECT:-${PROJECT:-library}}"
ROBOT_DESCRIPTION="${ROBOT_DESCRIPTION:-Robot account for CI/CD builds}"

# Harbor API endpoint
HARBOR_API="https://${HARBOR_URL}/api/v2.0"

echo "Creating Harbor robot account..."
echo ""
echo "Configuration:"
echo "  Harbor URL: ${HARBOR_URL}"
echo "  Project: ${PROJECT}"
echo "  Robot Name: ${ROBOT_NAME}"
echo ""

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo "Error: jq is required but not installed. Install with: sudo apt install jq"
    exit 1
fi

# Authenticate using basic auth (Harbor API v2.0 supports basic auth)
echo "Authenticating as admin..."
AUTH_TEST=$(curl -s -k -u "${HARBOR_ADMIN_USER}:${HARBOR_ADMIN_PASSWORD}" \
  "${HARBOR_API}/users/current" | jq -r '.username // empty')

if [ -z "$AUTH_TEST" ] || [ "$AUTH_TEST" != "admin" ]; then
    echo "Error: Failed to authenticate. Check your Harbor admin credentials."
    exit 1
fi

echo "✓ Authenticated"
echo ""

# Check if project exists
echo "Checking if project '${PROJECT}' exists..."
PROJECT_EXISTS=$(curl -s -k -u "${HARBOR_ADMIN_USER}:${HARBOR_ADMIN_PASSWORD}" \
  -X GET "${HARBOR_API}/projects?name=${PROJECT}" \
  | jq -r ".[] | select(.name == \"${PROJECT}\") | .name")

if [ -z "$PROJECT_EXISTS" ]; then
    echo "Project '${PROJECT}' does not exist. Creating it..."
    curl -s -k -u "${HARBOR_ADMIN_USER}:${HARBOR_ADMIN_PASSWORD}" \
      -X POST "${HARBOR_API}/projects" \
      -H "Content-Type: application/json" \
      -d "{
        \"project_name\": \"${PROJECT}\",
        \"public\": false,
        \"metadata\": {
          \"public\": \"false\"
        }
      }" > /dev/null
    echo "✓ Project '${PROJECT}' created"
else
    echo "✓ Project '${PROJECT}' exists"
fi
echo ""

# Create robot account
echo "Creating robot account '${ROBOT_NAME}' in project '${PROJECT}'..."
ROBOT_RESPONSE=$(curl -s -k -u "${HARBOR_ADMIN_USER}:${HARBOR_ADMIN_PASSWORD}" \
  -X POST "${HARBOR_API}/robots" \
  -H "Content-Type: application/json" \
  -d "{
    \"name\": \"${ROBOT_NAME}\",
    \"description\": \"${ROBOT_DESCRIPTION}\",
    \"level\": \"project\",
    \"duration\": -1,
    \"disable\": false,
    \"permissions\": [
      {
        \"kind\": \"project\",
        \"namespace\": \"${PROJECT}\",
        \"access\": [
          {
            \"resource\": \"repository\",
            \"action\": \"push\"
          },
          {
            \"resource\": \"repository\",
            \"action\": \"pull\"
          },
          {
            \"resource\": \"artifact\",
            \"action\": \"read\"
          },
          {
            \"resource\": \"artifact\",
            \"action\": \"create\"
          }
        ]
      }
    ]
  }")

ROBOT_SECRET=$(echo "$ROBOT_RESPONSE" | jq -r '.secret // empty')
ROBOT_FULL_NAME=$(echo "$ROBOT_RESPONSE" | jq -r '.name // empty')

if [ -z "$ROBOT_SECRET" ] || [ "$ROBOT_SECRET" = "null" ]; then
    echo "Error: Failed to create robot account"
    echo "Response: $ROBOT_RESPONSE"
    exit 1
fi

echo "✓ Robot account created successfully"
echo ""
echo "Robot Account Details:"
echo "  Full Name: ${ROBOT_FULL_NAME}"
echo "  Secret: ${ROBOT_SECRET}"
echo ""
echo "Add these to your .env file:"
echo "  HARBOR_ROBOT_ACCOUNT_NAME=${ROBOT_NAME}"
echo "  HARBOR_ROBOT_ACCOUNT_SECRET=${ROBOT_SECRET}"
echo "  HARBOR_ROBOT_ACCOUNT_FULL_NAME=${ROBOT_FULL_NAME}"
echo ""
echo "Docker login example:"
echo "  docker login ${HARBOR_URL} -u '${ROBOT_FULL_NAME}' -p '${ROBOT_SECRET}'"
echo ""
echo "⚠️  Save the robot secret now - it cannot be retrieved later!"
echo "   If you lose it, you'll need to delete and recreate the robot account."
