#!/bin/bash
# Create GitHub Actions Runner Controller authentication secret
#
# This script creates a Kubernetes secret for GitHub authentication.
# Supports both Personal Access Token (PAT) and GitHub App methods.

set -e

NAMESPACE="actions-runner-system"
SECRET_NAME="actions-runner-controller"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}GitHub Actions Runner Controller Secret Creation${NC}"
echo "=================================================="
echo ""

# Check if namespace exists, create if not
if ! kubectl get namespace "$NAMESPACE" &>/dev/null; then
    echo -e "${YELLOW}Namespace $NAMESPACE does not exist. Creating...${NC}"
    kubectl create namespace "$NAMESPACE"
    echo -e "${GREEN}Namespace created.${NC}"
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

# Choose authentication method
echo ""
echo "Select authentication method:"
echo "1) Personal Access Token (PAT)"
echo "2) GitHub App"
read -p "Enter choice (1 or 2): " -n 1 -r
echo

if [[ $REPLY =~ ^[1]$ ]]; then
    # PAT method
    echo ""
    echo -e "${YELLOW}Personal Access Token Method${NC}"
    echo "Create a PAT at: https://github.com/settings/tokens"
    echo "Required scope: repo"
    echo ""
    read -sp "Enter GitHub Personal Access Token: " GITHUB_TOKEN
    echo ""
    
    if [ -z "$GITHUB_TOKEN" ]; then
        echo -e "${RED}Error: Token cannot be empty.${NC}"
        exit 1
    fi
    
    # Create secret with PAT
    kubectl create secret generic "$SECRET_NAME" \
        --from-literal=github_token="$GITHUB_TOKEN" \
        -n "$NAMESPACE"
    
    echo -e "${GREEN}Secret created successfully using PAT method.${NC}"
    
elif [[ $REPLY =~ ^[2]$ ]]; then
    # GitHub App method
    echo ""
    echo -e "${YELLOW}GitHub App Method${NC}"
    echo "You need: App ID, Installation ID, and Private Key"
    echo ""
    read -p "Enter GitHub App ID: " APP_ID
    read -p "Enter GitHub App Installation ID: " INSTALLATION_ID
    echo "Enter GitHub App Private Key (paste the entire key, press Enter, then Ctrl+D to finish):"
    PRIVATE_KEY=$(cat)
    
    if [ -z "$APP_ID" ] || [ -z "$INSTALLATION_ID" ] || [ -z "$PRIVATE_KEY" ]; then
        echo -e "${RED}Error: App ID, Installation ID, and Private Key are required.${NC}"
        exit 1
    fi
    
    # Create secret with GitHub App credentials
    kubectl create secret generic "$SECRET_NAME" \
        --from-literal=github_app_id="$APP_ID" \
        --from-literal=github_app_installation_id="$INSTALLATION_ID" \
        --from-literal=github_app_private_key="$PRIVATE_KEY" \
        -n "$NAMESPACE"
    
    echo -e "${GREEN}Secret created successfully using GitHub App method.${NC}"
else
    echo -e "${RED}Invalid choice. Aborting.${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}Secret '$SECRET_NAME' created in namespace '$NAMESPACE'.${NC}"
echo ""
echo "Verify the secret:"
echo "  kubectl get secret $SECRET_NAME -n $NAMESPACE"
echo ""
echo "The GitHub Actions Runner Controller can now authenticate with GitHub."
