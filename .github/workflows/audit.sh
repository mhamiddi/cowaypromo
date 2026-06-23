#!/bin/bash
set -euo pipefail
URL="$1"
PROJECT="$2"
SOURCE_DIR="$3"

echo "=== Post-Deploy Audit: $PROJECT ==="

# Phase 1: HTTP + HTML integrity
echo "--- Phase 1: Load & Verify ---"
HTTP=$(curl -sI "$URL" 2>/dev/null | head -1)
echo "HTTP: $HTTP"

SIZE=$(curl -sL "$URL" 2>/dev/null | wc -c)
echo "HTML size: $SIZE bytes"

CLOSE=$(curl -sL "$URL" 2>/dev/null | grep -c '</html>' || echo 0)
echo "</html> count: $CLOSE"

CORRUPT=$(curl -sL "$URL" 2>/dev/null | grep -c "OUTPUT TRUNCATED" || echo 0)
echo "Corruption markers: $CORRUPT"

# Phase 2: Image audit
echo "--- Phase 2: Image Audit ---"
IMG_COUNT=$(curl -sL "$URL" 2>/dev/null | grep -o '<img' | wc -l)
echo "Total <img> tags: $IMG_COUNT"

# Check first 5 images for 200 + image content-type
curl -sL "$URL" 2>/dev/null | grep -oP 'src="[^"]*\.(jpg|jpeg|png|webp|gif)"' | head -10 | while read -r ref; do
  src=$(echo "$ref" | sed 's/src="//;s/"//')
  if echo "$src" | grep -q '^https://'; then
    full="$src"
  else
    full="$URL/$src"
  fi
  full="${full// /%20}"
  status=$(curl -s -o /dev/null -w "%{http_code}" "$full" 2>/dev/null || echo "000")
  ctype=$(curl -sI "$full" 2>/dev/null | grep -i 'content-type' | head -1 | tr -d '\r' || echo "NONE")
  if [ "$status" != "200" ] || ! echo "$ctype" | grep -qi "image/"; then
    echo "BROKEN: $status | $ctype | $src"
  fi
done

echo "=== Audit complete ==="
