#!/bin/bash
# Non-interactive script to create runner secrets
# Usage: 
#   GITHUB_TOKEN=<token> GITLAB_TOKEN=<token> GITLAB_URL=<url> ./scripts/create-secrets.sh
#   OR
#   ./scripts/create-secrets.sh <github-token> <gitlab-token> <gitlab-url>

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Get tokens from args or env
if [ $# -eq 3 ]; then
    GITHUB_TOKEN="$1"
    GITLAB_TOKEN="$2"
    GITLAB_URL="$3"
elif [ -n "$GITHUB_TOKEN" ] && [ -n "$GITLAB_TOKEN" ] && [ -n "$GITLAB_URL" ]; then
    echo -e "${YELLOW}Using tokens from environment variables${NC}"
else
    echo -e "${RED}Usage: $0 <github-token> <gitlab-token> <gitlab-url>${NC}"
    echo -e "${RED}   OR set GITHUB_TOKEN, GITLAB_TOKEN, GITLAB_URL environment variables${NC}"
    exit 1
fi

# Create namespaces
echo -e "${GREEN}Creating namespaces...${NC}"
kubectl create namespace managed-cicd --dry-run=client -o yaml | kubectl apply -f - > /dev/null
kubectl create namespace actions-runner-system --dry-run=client -o yaml | kubectl apply -f - > /dev/null

# Create GitHub secret
if [ -n "$GITHUB_TOKEN" ]; then
    echo -e "${GREEN}Creating GitHub runner secret...${NC}"
    if kubectl get secret actions-runner-controller -n actions-runner-system &>/dev/null; then
        kubectl delete secret actions-runner-controller -n actions-runner-system > /dev/null 2>&1
    fi
    kubectl create secret generic actions-runner-controller \
        --from-literal=github_token="$GITHUB_TOKEN" \
        -n actions-runner-system > /dev/null
    echo -e "${GREEN}✓ GitHub secret created${NC}"
fi

# Create GitLab secret
if [ -n "$GITLAB_TOKEN" ]; then
    echo -e "${GREEN}Creating GitLab runner secret...${NC}"
    if kubectl get secret gitlab-runner-secret -n managed-cicd &>/dev/null; then
        kubectl delete secret gitlab-runner-secret -n managed-cicd > /dev/null 2>&1
    fi
    kubectl create secret generic gitlab-runner-secret \
        --from-literal=runner-registration-token="$GITLAB_TOKEN" \
        -n managed-cicd > /dev/null
    echo -e "${GREEN}✓ GitLab secret created${NC}"
fi

echo -e "${GREEN}All secrets created successfully!${NC}"
