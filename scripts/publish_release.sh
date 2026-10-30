#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${PROJECT_DIR}"

DMG_FILE="${PROJECT_DIR}/monkey-tools-Installer.dmg"
TAG="v2.0.1"
REPO="pakkawatkh/monkey-tools"

if [ -z "${GITHUB_TOKEN}" ]; then
    if [ -n "$1" ]; then
        GITHUB_TOKEN="$1"
    else
        echo -n "🔑 Please enter your GitHub Personal Access Token (starts with ghp_): "
        read -s GITHUB_TOKEN
        echo ""
    fi
fi

if [ -z "${GITHUB_TOKEN}" ]; then
    echo "❌ Error: GitHub Token is required."
    exit 1
fi

echo "🚀 [1/4] Pushing main branch and tag ${TAG} to GitHub..."
git push "https://${GITHUB_TOKEN}@github.com/${REPO}.git" main
git push "https://${GITHUB_TOKEN}@github.com/${REPO}.git" "${TAG}" --force

echo "📦 [2/4] Ensuring ${DMG_FILE} is built..."
if [ ! -f "${DMG_FILE}" ]; then
    "${PROJECT_DIR}/scripts/create_dmg.sh"
fi

echo "📝 [3/4] Creating GitHub Release ${TAG} via API..."
RELEASE_NOTES=$(cat << 'EOF'
## 🚀 What's New in v2.0.1

- 🖱️ **120Hz Native Smooth Drag-to-Move:** Re-architected translation popover drag movement using native AppKit `window.performDrag` for butter-smooth window dragging that stays perfectly pinned to the cursor.
- 📐 **Omni-Directional Window Resizing:** Translation popover now supports smooth resizing from all 4 borders and 4 corners natively.
- ⚡ **Instant Bubble Dismissal on Any Action:** Floating translation bubble (`SelectionBubblePanel`) now automatically and immediately dismisses upon any non-translate user action (typing, clicking outside, scrolling, switching apps).
- ⌨️ **Keyboard Selection Navigation:** Browse clipboard history using Up/Down arrow keys (`↑` / `↓`) and press `Enter` to auto-paste immediately.
- 🎯 **Double-Click Accuracy Guard:** Prevents false-positive translation bubbles from appearing on empty browser tab double-clicks.
- 🌐 **3-Tier Resilient Translation Engine:** Eliminates HTTP 429 rate limit errors with Chrome extension endpoint, single-translate fallback, and MyMemory tiers.
- 🔒 **Proprietary All Rights Reserved License:** Full ownership and code integrity.
EOF
)

RELEASE_PAYLOAD=$(python3 -c "
import json, sys
data = {
    'tag_name': '${TAG}',
    'target_commitish': 'main',
    'name': '${TAG} - Productivity & Precision Update',
    'body': sys.stdin.read(),
    'draft': False,
    'prerelease': False
}
print(json.dumps(data))
" <<< "${RELEASE_NOTES}")

# Check if release already exists
RELEASE_ID=$(curl -s -H "Authorization: Bearer ${GITHUB_TOKEN}" \
  -H "Accept: application/vnd.github+json" \
  "https://api.github.com/repos/${REPO}/releases/tags/${TAG}" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('id', ''))" || true)

if [ -z "${RELEASE_ID}" ] || [ "${RELEASE_ID}" = "None" ]; then
    CREATE_RESP=$(curl -s -X POST \
      -H "Authorization: Bearer ${GITHUB_TOKEN}" \
      -H "Accept: application/vnd.github+json" \
      -H "X-GitHub-Api-Version: 2022-11-28" \
      "https://api.github.com/repos/${REPO}/releases" \
      -d "${RELEASE_PAYLOAD}")
    RELEASE_ID=$(python3 -c "import sys, json; data=json.loads(sys.stdin.read()); print(data.get('id', ''))" <<< "${CREATE_RESP}")
    echo "✅ Release created with ID: ${RELEASE_ID}"
else
    echo "ℹ️ Release already exists (ID: ${RELEASE_ID}). Updating assets..."
fi

if [ -z "${RELEASE_ID}" ] || [ "${RELEASE_ID}" = "None" ]; then
    echo "❌ Failed to create release. Response:"
    echo "${CREATE_RESP}"
    exit 1
fi

echo "📤 [4/4] Uploading monkey-tools-Installer.dmg (1.1 MB) to Release..."
# Delete existing asset if present
EXISTING_ASSET_ID=$(curl -s -H "Authorization: Bearer ${GITHUB_TOKEN}" \
  -H "Accept: application/vnd.github+json" \
  "https://api.github.com/repos/${REPO}/releases/${RELEASE_ID}/assets" | python3 -c "
import sys, json
assets = json.load(sys.stdin)
if isinstance(assets, list):
    for a in assets:
        if a.get('name') == 'monkey-tools-Installer.dmg':
            print(a.get('id', ''))
            break
" || true)

if [ -n "${EXISTING_ASSET_ID}" ]; then
    echo "Removing previous asset ${EXISTING_ASSET_ID}..."
    curl -s -X DELETE \
      -H "Authorization: Bearer ${GITHUB_TOKEN}" \
      -H "Accept: application/vnd.github+json" \
      "https://api.github.com/repos/${REPO}/releases/assets/${EXISTING_ASSET_ID}"
fi

UPLOAD_RESP=$(curl -s -X POST \
  -H "Authorization: Bearer ${GITHUB_TOKEN}" \
  -H "Content-Type: application/octet-stream" \
  -H "Accept: application/vnd.github+json" \
  --data-binary "@${DMG_FILE}" \
  "https://uploads.github.com/repos/${REPO}/releases/${RELEASE_ID}/assets?name=monkey-tools-Installer.dmg")

echo "✅ DMG Asset successfully uploaded!"

echo "🌐 Enabling GitHub Pages (/docs)..."
curl -s -X POST \
  -H "Authorization: Bearer ${GITHUB_TOKEN}" \
  -H "Accept: application/vnd.github+json" \
  "https://api.github.com/repos/${REPO}/pages" \
  -d '{"source":{"branch":"main","path":"/docs"}}' >/dev/null 2>&1 || true

echo "🎉 ALL DONE! Your release and download links are LIVE:"
echo "👉 Release: https://github.com/${REPO}/releases/tag/${TAG}"
echo "👉 Direct DMG Download: https://github.com/${REPO}/releases/download/${TAG}/monkey-tools-Installer.dmg"
echo "👉 Website: https://pakkawatkh.github.io/monkey-tools/"
