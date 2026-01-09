#!/bin/bash
# Update GitLab Runner registration token from Kubernetes secret
# This script extracts the token from the secret and updates the helmchart
# to avoid committing the token to git

set -e

NAMESPACE="${NAMESPACE:-managed-cicd}"
SECRET_NAME="${SECRET_NAME:-gitlab-runner-secret}"
HELMCHART_FILE="${HELMCHART_FILE:-gitlab-runner/overlays/nprd-apps/gitlab-runner-helmchart.yaml}"

echo "Updating GitLab Runner registration token from Kubernetes secret..."
echo ""

# Check if secret exists
if ! kubectl get secret "$SECRET_NAME" -n "$NAMESPACE" &>/dev/null; then
    echo "Error: Secret '$SECRET_NAME' not found in namespace '$NAMESPACE'"
    echo ""
    echo "Create the secret first:"
    echo "  kubectl create secret generic $SECRET_NAME \\"
    echo "    --from-literal=runner-registration-token='<YOUR_TOKEN>' \\"
    echo "    -n $NAMESPACE"
    exit 1
fi

# Extract token from secret
echo "Extracting token from secret..."
TOKEN=$(kubectl get secret "$SECRET_NAME" -n "$NAMESPACE" \
  -o jsonpath='{.data.runner-registration-token}' | base64 -d)

if [ -z "$TOKEN" ] || [ "$TOKEN" = "null" ]; then
    echo "Error: Failed to extract token from secret"
    exit 1
fi

echo "✓ Token extracted successfully"
echo ""

# Check if helmchart file exists
if [ ! -f "$HELMCHART_FILE" ]; then
    echo "Error: HelmChart file not found: $HELMCHART_FILE"
    exit 1
fi

# Update the helmchart file
echo "Updating helmchart file: $HELMCHART_FILE"
sed -i "s|runnerRegistrationToken:.*|runnerRegistrationToken: \"$TOKEN\"|" "$HELMCHART_FILE"

echo "✓ HelmChart file updated"
echo ""
echo "Next steps:"
echo "  1. Review the changes: git diff $HELMCHART_FILE"
echo "  2. Commit and push: git add $HELMCHART_FILE && git commit -m 'chore: update GitLab runner token from secret' && git push"
echo ""
echo "⚠️  Note: The token is now in the helmchart file but will be removed from"
echo "   git history after you rotate the token and clean history again."
