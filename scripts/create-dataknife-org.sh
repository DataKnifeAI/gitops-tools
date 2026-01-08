#!/bin/bash
# Guide to create DataKnife organization on GitHub
# Note: Organizations must be created via GitHub web UI

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}DataKnife Organization Setup${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

echo -e "${YELLOW}GitHub organizations must be created via the web interface.${NC}"
echo ""
echo "Follow these steps:"
echo ""
echo "1. Open your browser and go to:"
echo -e "   ${GREEN}https://github.com/organizations/new${NC}"
echo ""
echo "2. Fill in the form:"
echo "   - Organization account name: ${GREEN}DataKnife${NC}"
echo "   - Contact email: (your email)"
echo "   - Choose plan: ${GREEN}Free${NC} (or paid if needed)"
echo ""
echo "3. Click 'Create organization'"
echo ""
echo "4. After creation, verify the organization exists:"
echo "   ${GREEN}https://github.com/DataKnife${NC}"
echo ""
echo "5. The runner configuration has already been updated to use 'DataKnife'"
echo "   Once the org exists, Fleet will deploy runners automatically!"
echo ""
echo -e "${YELLOW}Note:${NC} Make sure your GitHub token has access to the DataKnife organization"
echo "      You may need to regenerate the token with org permissions"
echo ""

# Check if org exists
echo "Checking if DataKnife organization exists..."
if curl -s "https://api.github.com/orgs/DataKnife" | grep -q '"login"'; then
    echo -e "${GREEN}✓ DataKnife organization exists!${NC}"
    echo ""
    echo "Runner configuration is ready. Fleet will deploy automatically."
else
    echo -e "${YELLOW}⚠ DataKnife organization not found yet${NC}"
    echo "   Please create it using the steps above"
fi
