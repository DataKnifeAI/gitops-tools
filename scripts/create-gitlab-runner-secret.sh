#!/bin/bash
# Create GitLab Runner registration token secret
#
# This script creates a Kubernetes secret for GitLab Runner registration.

set -e

NAMESPACE="managed-cicd"
SECRET_NAME="gitlab-runner-secret"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}GitLab Runner Secret Creation${NC}"
echo "=================================="
echo ""

# Check if namespace exists
if ! kubectl get namespace "$NAMESPACE" &>/dev/null; then
    echo -e "${RED}Error: Namespace $NAMESPACE does not exist.${NC}"
    echo "Please create it first: kubectl create namespace $NAMESPACE"
    exit 1
fi

# Check if secret already exists
if kubectl get secret "$SECRET_NAME" -n "$NAMESPACE" &>/dev/null; then
    echo -e "${YELLOW}Secret $SECRET_NAME already exists in namespace $NAMESPACE.${NC}"
    read -p "Do you want to delete and recreate it? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        kubectl delete secret "$SECRET_NAME" -n "$NAMESPACE"
        echo -e "${GREEN}Existing secret deleted.${NC}"
    else
        echo -e "${YELLOW}Aborting.${NC}"
        exit 0
    fi
fi

# Get runner token
echo ""
echo "Obtain a runner registration token from GitLab:"
echo "  - Project-level: Settings → CI/CD → Runners → Registration token"
echo "  - Group-level: Group Settings → CI/CD → Runners → Registration token"
echo "  - Instance-level: Admin Area → Overview → Runners → Registration token"
echo ""
read -sp "Enter GitLab Runner Registration Token: " RUNNER_TOKEN
echo ""

if [ -z "$RUNNER_TOKEN" ]; then
    echo -e "${RED}Error: Token cannot be empty.${NC}"
    exit 1
fi

# Create secret
kubectl create secret generic "$SECRET_NAME" \
    --from-literal=runner-registration-token="$RUNNER_TOKEN" \
    -n "$NAMESPACE"

echo ""
echo -e "${GREEN}Secret '$SECRET_NAME' created in namespace '$NAMESPACE'.${NC}"
echo ""
echo "Verify the secret:"
echo "  kubectl get secret $SECRET_NAME -n $NAMESPACE"
echo ""
echo "To use this secret, you can:"
echo "  1. Use Fleet HelmChartConfig to inject the token from the secret"
echo "  2. Or manually set runnerRegistrationToken in gitlab-runner-helmchart.yaml"
echo "     (extract token: kubectl get secret $SECRET_NAME -n managed-cicd -o jsonpath='{.data.runner-registration-token}' | base64 -d)"
