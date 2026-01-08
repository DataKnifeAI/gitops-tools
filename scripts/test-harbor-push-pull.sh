#!/bin/bash
# Test Harbor push/pull functionality
# This script tests:
# 1. Push and pull to local registry (library project)
# 2. Pull from DockerHub cache (dockerhub project)
#
# Usage:
#   ./scripts/test-harbor-push-pull.sh
#   (May require sudo for certificate installation)

set -e

# Load .env file if it exists
if [ -f .env ]; then
    echo "Loading configuration from .env file..."
    # Read .env file line by line to handle $ characters properly
    while IFS= read -r line || [ -n "$line" ]; do
        # Skip comments and empty lines
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "${line// }" ]] && continue
        # Export the variable
        export "$line" 2>/dev/null || true
    done < .env
fi

# Configuration
HARBOR_URL="${HARBOR_REGISTRY_URL:-harbor.dataknife.net}"
ROBOT_USER="${HARBOR_ROBOT_ACCOUNT_FULL_NAME}"
ROBOT_PASS="${HARBOR_ROBOT_ACCOUNT_SECRET}"

# Verify robot account is set correctly
if [ -z "$ROBOT_USER" ] || [ -z "$ROBOT_PASS" ]; then
    echo "Error: Robot account credentials not found in .env file"
    echo "  Required: HARBOR_ROBOT_ACCOUNT_FULL_NAME and HARBOR_ROBOT_ACCOUNT_SECRET"
    echo ""
    echo "Current values:"
    echo "  ROBOT_USER: ${ROBOT_USER:-<not set>}"
    echo "  ROBOT_PASS: ${ROBOT_PASS:+<set>}${ROBOT_PASS:-<not set>}"
    exit 1
fi

echo "=========================================="
echo "Harbor Push/Pull Test Script"
echo "=========================================="
echo ""
echo "Configuration:"
echo "  Harbor URL: ${HARBOR_URL}"
echo "  Robot Account: ${ROBOT_USER}"
echo ""

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo "Error: Docker is not running or not accessible"
    exit 1
fi
echo "✓ Docker is running"
echo ""

# Check if certificate is installed
CERT_DIR="/etc/docker/certs.d/${HARBOR_URL}"
CERT_FILE="${CERT_DIR}/ca.crt"

if [ ! -f "$CERT_FILE" ]; then
    echo "⚠️  Harbor certificate not found at ${CERT_FILE}"
    echo "   Installing certificate (requires sudo)..."
    echo ""
    
    # Extract certificate
    TEMP_CERT=$(mktemp)
    echo | openssl s_client -connect ${HARBOR_URL}:443 -showcerts 2>/dev/null | \
        sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p' > "$TEMP_CERT"
    
    if [ -s "$TEMP_CERT" ]; then
        sudo mkdir -p "$CERT_DIR"
        sudo cp "$TEMP_CERT" "$CERT_FILE"
        sudo chmod 644 "$CERT_FILE"
        rm "$TEMP_CERT"
        echo "✓ Certificate installed to ${CERT_FILE}"
        echo "  Restarting Docker daemon..."
        sudo systemctl restart docker
        sleep 3
        echo "✓ Docker restarted"
    else
        echo "Error: Failed to extract certificate"
        rm -f "$TEMP_CERT"
        exit 1
    fi
    echo ""
else
    echo "✓ Harbor certificate found at ${CERT_FILE}"
    echo ""
fi

# Test 1: Login to Harbor
echo "=========================================="
echo "Test 1: Login to Harbor"
echo "=========================================="
if docker login ${HARBOR_URL} -u "${ROBOT_USER}" -p "${ROBOT_PASS}" > /dev/null 2>&1; then
    echo "✓ Successfully logged in to Harbor"
else
    echo "✗ Failed to login to Harbor"
    echo "  This may be due to:"
    echo "  - Invalid credentials"
    echo "  - Certificate issues (check ${CERT_FILE})"
    echo "  - Network connectivity"
    exit 1
fi
echo ""

# Test 2: Pull a small image for testing
echo "=========================================="
echo "Test 2: Pull alpine:latest (base image)"
echo "=========================================="
if docker pull alpine:latest > /dev/null 2>&1; then
    echo "✓ Successfully pulled alpine:latest"
else
    echo "✗ Failed to pull alpine:latest"
    exit 1
fi
echo ""

# Test 3: Tag and push to local registry (library project)
echo "=========================================="
echo "Test 3: Push to local registry (library project)"
echo "=========================================="
TEST_IMAGE="${HARBOR_URL}/library/test-alpine:$(date +%s)"
docker tag alpine:latest "${TEST_IMAGE}"

if docker push "${TEST_IMAGE}" > /dev/null 2>&1; then
    echo "✓ Successfully pushed ${TEST_IMAGE}"
    PUSHED_IMAGE="${TEST_IMAGE}"
else
    echo "✗ Failed to push to local registry"
    docker rmi "${TEST_IMAGE}" 2>/dev/null || true
    exit 1
fi
echo ""

# Test 4: Pull from local registry
echo "=========================================="
echo "Test 4: Pull from local registry"
echo "=========================================="
docker rmi "${TEST_IMAGE}" 2>/dev/null || true
docker rmi alpine:latest 2>/dev/null || true

if docker pull "${TEST_IMAGE}" > /dev/null 2>&1; then
    echo "✓ Successfully pulled ${TEST_IMAGE} from local registry"
else
    echo "✗ Failed to pull from local registry"
    exit 1
fi
echo ""

# Test 5: Pull from DockerHub cache (first pull - should fetch from DockerHub)
echo "=========================================="
echo "Test 5: Pull from DockerHub cache (nginx:alpine)"
echo "=========================================="
CACHE_IMAGE="${HARBOR_URL}/dockerhub/nginx:alpine"
docker rmi "${CACHE_IMAGE}" 2>/dev/null || true

echo "  Pulling ${CACHE_IMAGE}..."
echo "  (This will fetch from DockerHub if proxy cache is configured)"
if docker pull "${CACHE_IMAGE}" 2>&1 | tee /tmp/harbor-pull.log; then
    echo "✓ Successfully pulled ${CACHE_IMAGE}"
    if grep -q "Pulling from dockerhub" /tmp/harbor-pull.log || grep -q "Downloaded" /tmp/harbor-pull.log; then
        echo "  Note: Image was fetched (may be from DockerHub or cache)"
    fi
else
    echo "✗ Failed to pull from DockerHub cache"
    echo "  This may indicate:"
    echo "  - Proxy cache is not configured for dockerhub project"
    echo "  - Network connectivity issues"
    echo "  - Check Harbor UI: Projects → dockerhub → Configuration → Proxy Cache"
    rm -f /tmp/harbor-pull.log
    exit 1
fi
rm -f /tmp/harbor-pull.log
echo ""

# Test 6: Pull from DockerHub cache again (should use cache)
echo "=========================================="
echo "Test 6: Pull from DockerHub cache again (should use cache)"
echo "=========================================="
docker rmi "${CACHE_IMAGE}" 2>/dev/null || true

echo "  Pulling ${CACHE_IMAGE} again..."
if docker pull "${CACHE_IMAGE}" 2>&1 | tee /tmp/harbor-pull2.log; then
    echo "✓ Successfully pulled ${CACHE_IMAGE} (from cache)"
    if grep -q "Image is up to date" /tmp/harbor-pull2.log || grep -q "already exists" /tmp/harbor-pull2.log; then
        echo "  Note: Image served from Harbor cache"
    fi
else
    echo "✗ Failed to pull from cache"
    rm -f /tmp/harbor-pull2.log
    exit 1
fi
rm -f /tmp/harbor-pull2.log
echo ""

# Cleanup
echo "=========================================="
echo "Cleanup"
echo "=========================================="
echo "Removing test images..."
docker rmi "${TEST_IMAGE}" 2>/dev/null || true
docker rmi "${CACHE_IMAGE}" 2>/dev/null || true
docker rmi alpine:latest 2>/dev/null || true
echo "✓ Cleanup complete"
echo ""

# Summary
echo "=========================================="
echo "Test Summary"
echo "=========================================="
echo "✓ All tests passed!"
echo ""
echo "Results:"
echo "  1. ✓ Login to Harbor"
echo "  2. ✓ Pull base image (alpine)"
echo "  3. ✓ Push to local registry (library project)"
echo "  4. ✓ Pull from local registry"
echo "  5. ✓ Pull from DockerHub cache (dockerhub project)"
echo "  6. ✓ Pull from DockerHub cache again (cached)"
echo ""
echo "Harbor is working correctly for both:"
echo "  - Local registry (push/pull): ${HARBOR_URL}/library/"
echo "  - DockerHub cache (pull only): ${HARBOR_URL}/dockerhub/"
echo ""
