#!/usr/bin/env bash
# Harbor Restore Script
#
# Restores container images from a harbor-backup output to Harbor.
# Uses repositories-list.txt and the images/ directory from the backup.
#
# Usage: HARBOR_URL=https://harbor.dataknife.net HARBOR_USER=admin HARBOR_PASS=... ./harbor-restore.sh BACKUP_DIR
#
# Options: SKIP_SSL=1 for self-signed certs
#          DRY_RUN=1 to list what would be restored without copying
#
set -euo pipefail

BACKUP_DIR="${1:-}"
HARBOR_URL="${HARBOR_URL:-https://harbor.dataknife.net}"
HARBOR_USER="${HARBOR_USER:-admin}"
HARBOR_PASS="${HARBOR_PASS:-}"
SKIP_SSL="${SKIP_SSL:-false}"
DRY_RUN="${DRY_RUN:-false}"

if [[ -z "$BACKUP_DIR" || ! -d "$BACKUP_DIR" ]]; then
  echo "Usage: HARBOR_PASS=... $0 BACKUP_DIR"
  echo "  BACKUP_DIR: output directory from harbor-backup.sh (contains images/ and settings/)"
  exit 1
fi

if [[ -z "$HARBOR_PASS" ]]; then
  echo "Error: HARBOR_PASS required"
  exit 1
fi

IMAGES_DIR="$BACKUP_DIR/images"
LIST_FILE="$BACKUP_DIR/settings/repositories-list.txt"

if [[ ! -d "$IMAGES_DIR" ]]; then
  echo "Error: images/ not found in $BACKUP_DIR"
  exit 1
fi

if [[ ! -f "$LIST_FILE" ]]; then
  echo "Error: settings/repositories-list.txt not found in $BACKUP_DIR"
  exit 1
fi

for cmd in skopeo; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "Error: skopeo required"
    exit 1
  fi
done

HARBOR_HOST="${HARBOR_URL#https://}"
HARBOR_HOST="${HARBOR_HOST#http://}"
HARBOR_HOST="${HARBOR_HOST%%/*}"
CREDS="${HARBOR_USER}:${HARBOR_PASS}"
SKOPEO_OPTS=(--dest-creds "$CREDS" --src-tls-verify=false)
[[ "$SKIP_SSL" == "true" ]] && SKOPEO_OPTS+=(--dest-tls-verify=false)

echo "=== Harbor Restore ==="
echo "Source: $BACKUP_DIR"
echo "Target: $HARBOR_HOST"
echo ""

COUNT=0
FAILED=0

for repo in $(grep -v '^$' "$LIST_FILE"); do
  PREFIX="${repo//\//_}_"
  for img_dir in "$IMAGES_DIR"/${PREFIX}*/; do
    [[ -d "$img_dir" ]] || continue
    dirname=$(basename "$img_dir")
    tag="${dirname#$PREFIX}"
    SRC="dir:$img_dir"
    DST="docker://${HARBOR_HOST}/${repo}:${tag}"
    echo -n "    ${repo}:${tag} ... "
    if [[ "$DRY_RUN" == "1" || "$DRY_RUN" == "true" ]]; then
      echo "OK (dry-run)"
      ((COUNT++)) || true
    elif skopeo copy "${SKOPEO_OPTS[@]}" "$SRC" "$DST" 2>/dev/null; then
      echo "OK"
      ((COUNT++)) || true
    else
      echo "FAILED"
      ((FAILED++)) || true
    fi
  done
done

echo ""
echo "=== Restore complete ==="
echo "Images: $COUNT"
[[ $FAILED -gt 0 ]] && echo "Failed: $FAILED"
