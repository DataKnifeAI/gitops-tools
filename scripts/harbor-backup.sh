#!/usr/bin/env bash
# Harbor Backup Script
#
# Downloads all container images from Harbor and exports settings.
# Requires: skopeo, curl, jq
# Usage: HARBOR_URL=https://harbor.dataknife.net HARBOR_USER=admin HARBOR_PASS=... ./harbor-backup.sh [OUTPUT_DIR]
#
# Options: SKIP_IMAGES=1 to only export settings (no skopeo needed)
#          SKIP_SSL=1 for self-signed certs
#          LIST_ONLY=1 to fetch repos and write lists only (verify exclusions, no download)
#
set -euo pipefail

HARBOR_URL="${HARBOR_URL:-https://harbor.dataknife.net}"
HARBOR_USER="${HARBOR_USER:-admin}"
HARBOR_PASS="${HARBOR_PASS:-}"
OUTPUT_DIR="${1:-./harbor-backup-$(date +%Y%m%d-%H%M%S)}"
SKIP_SSL="${SKIP_SSL:-false}"

if [[ -z "$HARBOR_PASS" ]]; then
  echo "Error: HARBOR_PASS required. Use: HARBOR_PASS=yourpass $0 [OUTPUT_DIR]"
  exit 1
fi

for cmd in curl jq; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "Error: $cmd required but not found. Install: curl, jq"
    exit 1
  fi
done

mkdir -p "$OUTPUT_DIR"/{images,settings}
API_BASE="${HARBOR_URL}/api/v2.0"
CURL_OPTS=(-s -u "${HARBOR_USER}:${HARBOR_PASS}")
[[ "$SKIP_SSL" == "true" ]] && CURL_OPTS+=(-k)

echo "=== Harbor Backup ==="
echo "URL: $HARBOR_URL"
echo "Output: $OUTPUT_DIR"
echo ""

# 1. Export settings (system config, projects, replication config)
echo "[1/3] Exporting Harbor settings..."
if ! curl "${CURL_OPTS[@]}" -f -s "${API_BASE}/systeminfo" -o "$OUTPUT_DIR/settings/systeminfo.json"; then
  echo "    Warning: systeminfo failed (check URL and credentials)"
  echo '{}' > "$OUTPUT_DIR/settings/systeminfo.json"
fi
curl "${CURL_OPTS[@]}" -s "${API_BASE}/configurations" -o "$OUTPUT_DIR/settings/configurations.json" 2>/dev/null || true
curl "${CURL_OPTS[@]}" -s "${API_BASE}/projects" -o "$OUTPUT_DIR/settings/projects.json" 2>/dev/null || echo '[]' > "$OUTPUT_DIR/settings/projects.json"
curl "${CURL_OPTS[@]}" "${API_BASE}/registries" -o "$OUTPUT_DIR/settings/registries.json" 2>/dev/null || true
curl "${CURL_OPTS[@]}" "${API_BASE}/labels" -o "$OUTPUT_DIR/settings/labels.json" 2>/dev/null || true
echo "    Saved to $OUTPUT_DIR/settings/"
echo ""

# 2. List all repositories (Harbor API - Registry v2 _catalog may use different auth)
echo "[2/3] Discovering repositories..."
HARBOR_HOST="${HARBOR_URL#https://}"
HARBOR_HOST="${HARBOR_HOST#http://}"
HARBOR_HOST="${HARBOR_HOST%%/*}"
REGISTRY_URL="${HARBOR_URL%/}/v2"

# Try Registry API v2 first
CATALOG=$(curl "${CURL_OPTS[@]}" "${REGISTRY_URL}/_catalog?n=10000" 2>/dev/null || echo '{"repositories":[]}')
ALL_REPOS=$(echo "$CATALOG" | jq -r '.repositories[]? // empty' 2>/dev/null | grep -v '^$' || true)

# Fallback: use Harbor API if registry catalog is empty or errors
if [[ -z "$ALL_REPOS" ]]; then
  echo "    Registry API empty, trying Harbor API..."
  for proj in $(jq -r '.[].name' "$OUTPUT_DIR/settings/projects.json" 2>/dev/null); do
    [[ "$proj" == "dockerhub" || "$proj" == "freya" ]] && continue
    REPOS_JSON=$(curl "${CURL_OPTS[@]}" "${API_BASE}/projects/${proj}/repositories?page_size=100" 2>/dev/null || echo "[]")
    ALL_REPOS="${ALL_REPOS}$(echo "$REPOS_JSON" | jq -r '.[].name // empty' 2>/dev/null)"$'\n'
  done
  ALL_REPOS=$(echo "$ALL_REPOS" | grep -v '^$' | sort -u)
fi

# Exclude DockerHub proxy cache and freya (grep -v exits 1 when no matches; use || true)
# dockerhub: ^dockerhub or ^dockerhub/
# freya: ^freya, freya/, or any path containing /freya or freya-
EXCLUDED=$(echo "$ALL_REPOS" | grep -E '^dockerhub($|/)|^freya($|/)|/freya|freya-' 2>/dev/null || true)
REPOS=$(echo "$ALL_REPOS" | grep -vE '^dockerhub($|/)|^freya($|/)|/freya|freya-' || true)

# Write lists for verification
echo "$ALL_REPOS" > "$OUTPUT_DIR/settings/repositories-all.txt"
echo "$EXCLUDED" > "$OUTPUT_DIR/settings/repositories-excluded.txt"
echo "$REPOS" > "$OUTPUT_DIR/settings/repositories-list.txt"

echo "    Excluded: dockerhub, freya"
EXCLUDED_COUNT=$(echo "$EXCLUDED" | grep -c . 2>/dev/null || echo 0)
REPO_COUNT=$(echo "$REPOS" | grep -c . 2>/dev/null || echo 0)
echo "    Excluded count: $EXCLUDED_COUNT (see repositories-excluded.txt)"
echo "    To backup: $REPO_COUNT (see repositories-list.txt)"
echo ""

if [[ "${LIST_ONLY:-0}" == "1" ]]; then
  echo "[3/3] LIST_ONLY=1 — skipping image download"
  echo ""
  echo "=== List complete ==="
  echo "Output: $OUTPUT_DIR/settings/"
  echo "  - repositories-all.txt     (all repos from Harbor)"
  echo "  - repositories-excluded.txt (dockerhub, freya — verify these are correct)"
  echo "  - repositories-list.txt    (repos to backup — iterate this list)"
  echo ""
  exit 0
fi

# 3. Download all images with skopeo
if [[ "${SKIP_IMAGES:-0}" == "1" ]]; then
  echo "[3/3] Skipping image download (SKIP_IMAGES=1)"
  COUNT=0
  FAILED=0
else
  if ! command -v skopeo &>/dev/null; then
    echo "Error: skopeo required for image backup. Install skopeo or use SKIP_IMAGES=1 for settings only."
    exit 1
  fi
  echo "[3/3] Downloading images (skopeo copy)..."
  CREDS="${HARBOR_USER}:${HARBOR_PASS}"
  SKOPEO_OPTS=(--src-creds "$CREDS" --dest-tls-verify=false)
  [[ "$SKIP_SSL" == "true" ]] && SKOPEO_OPTS+=(--src-tls-verify=false)

  COUNT=0
  FAILED=0
  for repo in $REPOS; do
  TAGS=$(curl "${CURL_OPTS[@]}" "${REGISTRY_URL}/${repo}/tags/list?n=1000" | jq -r '.tags[]? // "latest"' 2>/dev/null || echo "latest")
  for tag in $TAGS; do
    SRC="docker://${HARBOR_HOST}/${repo}:${tag}"
    DST="dir:$OUTPUT_DIR/images/${repo//\//_}_${tag}"
    echo -n "    ${repo}:${tag} ... "
    ERR=$(skopeo copy "${SKOPEO_OPTS[@]}" "$SRC" "$DST" 2>&1) && { echo "OK"; ((COUNT++)) || true; } || {
      echo "FAILED"
      [[ -n "$ERR" ]] && echo "        $ERR" | head -1
      ((FAILED++)) || true
    }
  done
  done
fi

echo ""
echo "=== Backup complete ==="
echo "Images: $COUNT"
[[ $FAILED -gt 0 ]] && echo "Failed: $FAILED"
echo "Output: $OUTPUT_DIR"
echo ""
echo "To restore: push images from $OUTPUT_DIR/images/ to new Harbor using skopeo copy."
