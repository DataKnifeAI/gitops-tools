#!/bin/bash
# Runner Configuration Script
# This script updates GitLab Runner authentication token in Kubernetes secret
#
# Usage:
#   ./scripts/runner-config.sh
#   RUNNER_TOKEN=glrt-xxx ./scripts/runner-config.sh

set -e

NAMESPACE="${NAMESPACE:-managed-cicd}"
SECRET_NAME="${SECRET_NAME:-gitlab-runner-secret}"
DEPLOYMENT_NAME="${DEPLOYMENT_NAME:-gitlab-runner}"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}Updating GitLab Runner authentication token in Kubernetes secret${NC}"
echo "Token will be stored in cluster only (never committed to git)."
echo ""

# Get token from env or secret
if [ -n "$RUNNER_TOKEN" ]; then
    TOKEN="$RUNNER_TOKEN"
    echo "Using token from RUNNER_TOKEN environment variable."
elif kubectl get secret "$SECRET_NAME" -n "$NAMESPACE" &>/dev/null; then
    echo "Extracting token from existing secret..."
    TOKEN=$(kubectl get secret "$SECRET_NAME" -n "$NAMESPACE" \
      -o jsonpath='{.data.runner-token}' 2>/dev/null | base64 -d || true)

    if [ -z "$TOKEN" ] || [ "$TOKEN" = "null" ]; then
        # Fall back to legacy key for migration
        TOKEN=$(kubectl get secret "$SECRET_NAME" -n "$NAMESPACE" \
          -o jsonpath='{.data.runner-registration-token}' | base64 -d)
    fi
else
    echo -e "${RED}Error: Secret '$SECRET_NAME' not found in namespace '$NAMESPACE'${NC}"
    echo ""
    echo "Create the secret first:"
    echo "  RUNNER_TOKEN=glrt-xxx ./scripts/runner-setup.sh gitlab"
    exit 1
fi

if [ -z "$TOKEN" ] || [ "$TOKEN" = "null" ]; then
    echo -e "${RED}Error: No runner token found.${NC}"
    echo ""
    echo "Create a runner in GitLab UI (Settings → CI/CD → Runners), copy the"
    echo "authentication token (glrt-*), then run:"
    echo "  RUNNER_TOKEN=glrt-xxx ./scripts/runner-setup.sh gitlab"
    exit 1
fi

if [[ ! "$TOKEN" == glrt-* ]]; then
    echo -e "${YELLOW}Warning: Token does not start with 'glrt-'. Registration tokens are deprecated.${NC}"
    echo "Create a runner in GitLab UI and use the authentication token instead."
    echo ""
fi

echo -e "${GREEN}✓ Token validated${NC}"
echo ""

# Create/update secret with new token format
kubectl create secret generic "$SECRET_NAME" \
  --from-literal=runner-registration-token="" \
  --from-literal=runner-token="$TOKEN" \
  -n "$NAMESPACE" \
  --dry-run=client -o yaml | kubectl apply -f -

echo ""
echo -e "${GREEN}✓ Secret updated successfully${NC}"
echo ""

# Restart runner pods to pick up new token
if kubectl get deployment "$DEPLOYMENT_NAME" -n "$NAMESPACE" &>/dev/null; then
    echo "Restarting runner deployment to pick up new token..."
    kubectl rollout restart deployment "$DEPLOYMENT_NAME" -n "$NAMESPACE"
    kubectl rollout status deployment "$DEPLOYMENT_NAME" -n "$NAMESPACE" --timeout=120s
    echo -e "${GREEN}✓ Runner deployment restarted${NC}"
else
    echo -e "${YELLOW}Deployment '$DEPLOYMENT_NAME' not found yet. Fleet will deploy on next sync.${NC}"
fi

echo ""
echo "✅ Token is now in:"
echo "   - Kubernetes secret: $SECRET_NAME (runner-token key)"
echo ""
echo "❌ Token is NOT in:"
echo "   - Git repository ✅"
echo "   - HelmChart values ✅"
