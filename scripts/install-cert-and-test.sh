#!/bin/bash
# Quick script to install certificate and test Harbor
# This script provides the commands you need to run

set -e

echo "=========================================="
echo "Harbor Certificate Installation & Test"
echo "=========================================="
echo ""
echo "The certificate is at: /tmp/harbor-cert.pem"
echo ""
echo "Run these commands:"
echo ""
echo "1. Install certificate:"
echo "   sudo mkdir -p /etc/docker/certs.d/harbor.dataknife.net"
echo "   sudo cp /tmp/harbor-cert.pem /etc/docker/certs.d/harbor.dataknife.net/ca.crt"
echo "   sudo chmod 644 /etc/docker/certs.d/harbor.dataknife.net/ca.crt"
echo ""
echo "2. Restart Docker:"
echo "   sudo systemctl restart docker"
echo ""
echo "3. Then run the test script:"
echo "   ./scripts/test-harbor-push-pull.sh"
echo ""
echo "Or test manually:"
echo "   source .env"
echo "   echo \"\${HARBOR_ROBOT_ACCOUNT_SECRET}\" | docker login harbor.dataknife.net -u \"\${HARBOR_ROBOT_ACCOUNT_FULL_NAME}\" --password-stdin"
echo "   docker tag alpine:latest harbor.dataknife.net/library/test-alpine:latest"
echo "   docker push harbor.dataknife.net/library/test-alpine:latest"
echo ""
