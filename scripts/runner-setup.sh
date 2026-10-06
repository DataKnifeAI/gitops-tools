#!/bin/bash
# Runner Setup Script
# This script creates the GitLab runner secret
#
# Usage:
#   ./scripts/runner-setup.sh [gitlab]
#   GITLAB_TOKEN=<token> GITLAB_URL=<url> ./scripts/runner-setup.sh gitlab

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

ACTION="${1:-gitlab}"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}GitLab Runner Setup${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Check kubectl
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}Error: kubectl is not installed or not in PATH${NC}"
    exit 1
fi

# Create namespace
echo -e "${YELLOW}Creating namespace...${NC}"
kubectl create namespace managed-cicd --dry-run=client -o yaml | kubectl apply -f - > /dev/null
echo -e "${GREEN}✓ Namespace created${NC}"
echo ""

# Function: Create GitLab secret
create_gitlab_secret() {
    echo -e "${YELLOW}=== GitLab Runner Setup ===${NC}"
    
    # Get URL and token from env or prompt
    if [ -z "$GITLAB_URL" ] || [ -z "$GITLAB_TOKEN" ]; then
        echo "For group-level runner (RaaS group), you need:"
        echo "  - GitLab instance URL"
        echo "  - Runner authentication token (glrt-*) from GitLab UI"
        echo ""
        echo "Create the runner in GitLab: Settings → CI/CD → Runners → New runner"
        echo ""
        read -p "Enter GitLab instance URL (e.g., https://gitlab.com): " GITLAB_URL
        read -sp "Enter GitLab Runner Authentication Token (glrt-*): " GITLAB_TOKEN
        echo ""
        
        if [ -z "$GITLAB_TOKEN" ]; then
            echo -e "${RED}Error: GitLab token cannot be empty${NC}"
            exit 1
        fi
    fi

    if [[ ! "$GITLAB_TOKEN" == glrt-* ]]; then
        echo -e "${YELLOW}Warning: Token does not start with 'glrt-'. Registration tokens are deprecated.${NC}"
        echo "Create a runner in GitLab UI and use the authentication token instead."
        echo ""
    fi
    
    # Check if secret exists
    if kubectl get secret gitlab-runner-secret -n managed-cicd &>/dev/null; then
        echo -e "${YELLOW}Secret already exists. Deleting...${NC}"
        kubectl delete secret gitlab-runner-secret -n managed-cicd
    fi
    
    kubectl create secret generic gitlab-runner-secret \
        --from-literal=runner-registration-token="" \
        --from-literal=runner-token="$GITLAB_TOKEN" \
        -n managed-cicd > /dev/null
    
    echo -e "${GREEN}✓ GitLab secret created${NC}"
    echo ""
}

# Main execution
case "$ACTION" in
    gitlab|all)
        create_gitlab_secret
        echo -e "${GREEN}========================================${NC}"
        echo -e "${GREEN}Setup Complete!${NC}"
        echo -e "${GREEN}========================================${NC}"
        echo ""
        echo "Next steps:"
        echo "1. Update gitlab-runner/base/gitlab-runner-helmchart.yaml with GitLab URL: ${GITLAB_URL:-<set in .env>}"
        echo "2. Commit and push changes"
        echo ""
        echo "To verify the secret:"
        echo "  kubectl get secret gitlab-runner-secret -n managed-cicd"
        ;;
    *)
        echo "Usage: $0 [gitlab]"
        echo ""
        echo "  gitlab  - Create GitLab runner secret (default; 'all' is an alias)"
        echo ""
        echo "Environment variables:"
        echo "  GITLAB_TOKEN  - GitLab runner authentication token (glrt-*)"
        echo "  GITLAB_URL    - GitLab instance URL"
        exit 1
        ;;
esac
