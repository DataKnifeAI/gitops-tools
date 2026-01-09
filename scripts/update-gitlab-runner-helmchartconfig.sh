#!/bin/bash
# Update GitLab Runner registration token in HelmChartConfig from Kubernetes secret
# This script updates the HelmChartConfig directly in the cluster - token never goes to git
#
# Usage:
#   ./scripts/update-gitlab-runner-helmchartconfig.sh
#
# This ensures the token is only stored in:
#   1. Kubernetes secret (gitlab-runner-secret)
#   2. HelmChartConfig in cluster (not in git)
#
# The token is NEVER committed to git repository

set -e

NAMESPACE="${NAMESPACE:-managed-cicd}"
SECRET_NAME="${SECRET_NAME:-gitlab-runner-secret}"
HELMCHARTCONFIG_NAME="gitlab-runner"

echo "Updating GitLab Runner registration token in HelmChartConfig..."
echo "Token will be extracted from Kubernetes secret and applied to cluster only."
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

# Escape the token for YAML (escape quotes and backslashes)
ESCAPED_TOKEN=$(echo "$TOKEN" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g')

# Create HelmChartConfig YAML content
VALUES_CONTENT="runnerRegistrationToken: \"$ESCAPED_TOKEN\""

# Check if HelmChartConfig exists
if kubectl get helmchartconfig "$HELMCHARTCONFIG_NAME" -n "$NAMESPACE" &>/dev/null; then
    echo "Updating existing HelmChartConfig..."
    # Update existing HelmChartConfig
    kubectl patch helmchartconfig "$HELMCHARTCONFIG_NAME" -n "$NAMESPACE" \
      --type='json' \
      -p="[{\"op\": \"replace\", \"path\": \"/spec/valuesContent\", \"value\": \"$VALUES_CONTENT\"}]"
else
    echo "Creating new HelmChartConfig..."
    # Create new HelmChartConfig
    cat <<EOF | kubectl apply -f -
apiVersion: helm.cattle.io/v1
kind: HelmChartConfig
metadata:
  name: $HELMCHARTCONFIG_NAME
  namespace: $NAMESPACE
spec:
  valuesContent: |-
    $VALUES_CONTENT
EOF
fi

echo ""
echo "✓ HelmChartConfig updated successfully"
echo ""
echo "✅ Token is now in:"
echo "   - Kubernetes secret: $SECRET_NAME"
echo "   - HelmChartConfig: $HELMCHARTCONFIG_NAME (in cluster only)"
echo ""
echo "❌ Token is NOT in:"
echo "   - Git repository ✅"
echo "   - Any committed files ✅"
echo ""
echo "Fleet will automatically merge the HelmChartConfig with the HelmChart."
echo "The runner should pick up the new token on the next sync."
