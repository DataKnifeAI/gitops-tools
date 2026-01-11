#!/bin/bash
# Update OpenSearch Bootstrap Webhook CA Bundle
#
# This script extracts the CA bundle from the webhook certificate secret
# and updates the MutatingWebhookConfiguration with the CA bundle.
#
# Prerequisites:
#   - cert-manager Certificate resource deployed
#   - Certificate secret exists: opensearch-bootstrap-webhook-cert
#   - MutatingWebhookConfiguration exists: opensearch-bootstrap-password-webhook
#
# Usage:
#   ./scripts/update-opensearch-webhook-ca-bundle.sh

set -e

NAMESPACE="managed-tools"
SECRET_NAME="opensearch-bootstrap-webhook-cert"
WEBHOOK_NAME="opensearch-bootstrap-password-webhook"

echo "Updating OpenSearch Bootstrap Webhook CA Bundle..."
echo ""

# Check if secret exists
if ! kubectl get secret "$SECRET_NAME" -n "$NAMESPACE" &>/dev/null; then
    echo "ERROR: Secret $SECRET_NAME not found in namespace $NAMESPACE"
    echo ""
    echo "Please ensure the Certificate resource is deployed and certificate is issued."
    echo "Check with: kubectl get certificate -n $NAMESPACE"
    exit 1
fi

# Extract CA bundle
echo "Extracting CA bundle from secret..."
CA_BUNDLE=$(kubectl get secret "$SECRET_NAME" -n "$NAMESPACE" -o jsonpath='{.data.ca\.crt}')

if [ -z "$CA_BUNDLE" ]; then
    # Try tls.crt if ca.crt doesn't exist (self-signed certificates)
    echo "CA bundle not found in secret. Checking if this is a self-signed certificate..."
    TLS_CRT=$(kubectl get secret "$SECRET_NAME" -n "$NAMESPACE" -o jsonpath='{.data.tls\.crt}')
    
    if [ -z "$TLS_CRT" ]; then
        echo "ERROR: No certificate data found in secret"
        exit 1
    fi
    
    # For self-signed certificates, use tls.crt as CA bundle
    echo "Using tls.crt as CA bundle (self-signed certificate)..."
    CA_BUNDLE="$TLS_CRT"
fi

# Check if webhook exists
if ! kubectl get mutatingwebhookconfiguration "$WEBHOOK_NAME" &>/dev/null; then
    echo "ERROR: MutatingWebhookConfiguration $WEBHOOK_NAME not found"
    echo ""
    echo "Please ensure the webhook configuration is deployed."
    exit 1
fi

# Update webhook configuration
echo "Updating MutatingWebhookConfiguration with CA bundle..."
kubectl patch mutatingwebhookconfiguration "$WEBHOOK_NAME" --type='json' \
  -p="[{\"op\": \"replace\", \"path\": \"/webhooks/0/clientConfig/caBundle\", \"value\": \"${CA_BUNDLE}\"}]"

echo ""
echo "✅ CA bundle updated successfully!"
echo ""
echo "Verify with:"
echo "  kubectl get mutatingwebhookconfiguration $WEBHOOK_NAME -o jsonpath='{.webhooks[0].clientConfig.caBundle}' | base64 -d | openssl x509 -text -noout"
