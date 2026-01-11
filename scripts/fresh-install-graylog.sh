#!/bin/bash
# Fresh Install Script for Graylog 7.x
# This script removes existing Graylog installation and prepares for fresh install

set -e

CONTEXT="${KUBECTL_CONTEXT:-nprd-apps}"
NAMESPACE="${NAMESPACE:-managed-graylog}"

echo "=== Graylog 7.x Fresh Install ==="
echo ""
echo "Context: $CONTEXT"
echo "Namespace: $NAMESPACE"
echo ""

# Confirm action
read -p "This will delete all Graylog resources. Continue? (yes/no): " CONFIRM
if [ "$CONFIRM" != "yes" ]; then
    echo "Aborted."
    exit 1
fi

echo ""
echo "Step 1: Deleting Graylog StatefulSet and Pods..."
kubectl --context "$CONTEXT" delete statefulset graylog -n "$NAMESPACE" --ignore-not-found=true
kubectl --context "$CONTEXT" delete pod -l app=graylog,component=server -n "$NAMESPACE" --ignore-not-found=true

echo ""
echo "Step 2: Deleting Graylog Helm Chart..."
kubectl --context "$CONTEXT" delete helmchart graylog -n "$NAMESPACE" --ignore-not-found=true

echo ""
echo "Step 3: Deleting Graylog Services..."
kubectl --context "$CONTEXT" delete svc graylog-syslog -n "$NAMESPACE" --ignore-not-found=true

echo ""
echo "Step 4: Deleting Graylog Ingress..."
kubectl --context "$CONTEXT" delete ingress graylog -n "$NAMESPACE" --ignore-not-found=true

echo ""
echo "Step 5: Deleting Graylog Jobs..."
kubectl --context "$CONTEXT" delete job -l app=graylog -n "$NAMESPACE" --ignore-not-found=true

echo ""
read -p "Delete Graylog PVCs (this will delete all logs)? (yes/no): " DELETE_PVC
if [ "$DELETE_PVC" = "yes" ]; then
    echo "Deleting Graylog PVCs..."
    kubectl --context "$CONTEXT" delete pvc -l app=graylog -n "$NAMESPACE" --ignore-not-found=true
    echo "✓ PVCs deleted"
else
    echo "Keeping PVCs (data preserved)"
fi

echo ""
echo "Step 6: Waiting for resources to be fully deleted..."
sleep 5

echo ""
echo "=== Cleanup Complete ==="
echo ""
echo "Next steps:"
echo "1. Fleet will automatically reinstall Graylog 7.x from GitOps"
echo "2. Monitor installation:"
echo "   kubectl get pods -n $NAMESPACE -w | grep graylog"
echo "3. Check Helm chart:"
echo "   kubectl get helmchart graylog -n $NAMESPACE"
echo ""
echo "Graylog 7.x will be installed with:"
echo "- Image: graylog/graylog:7.0 (stable version, latest is 7.0.3)"
echo "- OpenSearch: 2.19.3 (existing cluster)"
echo "- MongoDB: 7.0.25 (existing if PVCs kept)"
echo ""
echo "After installation, configure:"
echo "- Syslog input for UniFi CEF (see docs/graylog/UNIFI_CEF_SETUP.md)"
echo "- Verify at: https://graylog.dataknife.net"
