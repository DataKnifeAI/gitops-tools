#!/bin/bash
# Setup script for GitHub and GitLab runners
# This script creates secrets and configures runners for organization/group level

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}GitHub & GitLab Runner Setup${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Check kubectl
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}Error: kubectl is not installed or not in PATH${NC}"
    exit 1
fi

# Create namespaces
echo -e "${YELLOW}Creating namespaces...${NC}"
kubectl create namespace managed-cicd --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace actions-runner-system --dry-run=client -o yaml | kubectl apply -f -
echo -e "${GREEN}Namespaces created${NC}"
echo ""

# GitHub Runner Secret
echo -e "${YELLOW}=== GitHub Runner Setup ===${NC}"
echo "For organization-level runners, you need:"
echo "  - GitHub Personal Access Token (PAT) with 'repo' scope, OR"
echo "  - GitHub App credentials"
echo ""
read -p "Do you have a GitHub PAT? (y/n): " -n 1 -r
echo

if [[ $REPLY =~ ^[Yy]$ ]]; then
    read -sp "Enter GitHub Personal Access Token: " GITHUB_TOKEN
    echo ""
    
    if [ -z "$GITHUB_TOKEN" ]; then
        echo -e "${RED}Error: Token cannot be empty${NC}"
        exit 1
    fi
    
    # Check if secret exists
    if kubectl get secret actions-runner-controller -n actions-runner-system &>/dev/null; then
        echo -e "${YELLOW}Secret already exists. Deleting...${NC}"
        kubectl delete secret actions-runner-controller -n actions-runner-system
    fi
    
    kubectl create secret generic actions-runner-controller \
        --from-literal=github_token="$GITHUB_TOKEN" \
        -n actions-runner-system
    
    echo -e "${GREEN}GitHub secret created${NC}"
else
    echo -e "${YELLOW}Skipping GitHub secret creation. You can create it later with:${NC}"
    echo "  ./scripts/create-github-runner-secret.sh"
fi
echo ""

# GitLab Runner Secret
echo -e "${YELLOW}=== GitLab Runner Setup ===${NC}"
echo "For group-level runner (RaaS group), you need:"
echo "  - GitLab instance URL"
echo "  - Group runner registration token"
echo ""
read -p "Enter GitLab instance URL (e.g., https://gitlab.com): " GITLAB_URL
read -sp "Enter GitLab Group Runner Registration Token: " GITLAB_TOKEN
echo ""

if [ -z "$GITLAB_TOKEN" ]; then
    echo -e "${RED}Error: GitLab token cannot be empty${NC}"
    exit 1
fi

# Check if secret exists
if kubectl get secret gitlab-runner-secret -n managed-cicd &>/dev/null; then
    echo -e "${YELLOW}Secret already exists. Deleting...${NC}"
    kubectl delete secret gitlab-runner-secret -n managed-cicd
fi

kubectl create secret generic gitlab-runner-secret \
    --from-literal=runner-registration-token="$GITLAB_TOKEN" \
    -n managed-cicd

echo -e "${GREEN}GitLab secret created${NC}"
echo ""

# Update GitLab HelmChart with URL and token
echo -e "${YELLOW}Updating GitLab Runner configuration...${NC}"
# We'll need to update the helmchart file - this will be done in the next step
echo -e "${GREEN}Configuration will be updated in git${NC}"
echo ""

# Summary
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Setup Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Next steps:"
echo "1. Update github-runner/base/runnerdeployment.yaml with your GitHub organization"
echo "2. Update gitlab-runner/base/gitlab-runner-helmchart.yaml with GitLab URL: $GITLAB_URL"
echo "3. Commit and push changes"
echo ""
echo "To verify secrets:"
echo "  kubectl get secret actions-runner-controller -n actions-runner-system"
echo "  kubectl get secret gitlab-runner-secret -n managed-cicd"
