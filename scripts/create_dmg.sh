#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${PROJECT_DIR}"

echo "🔨 Ensuring latest release build of monkey-tools.app..."
./scripts/build_app.sh

if [ -d "$(cd "${PROJECT_DIR}/.." && pwd)/public" ]; then
    PLIW_MONKEY_DIR="$(cd "${PROJECT_DIR}/.." && pwd)/public/monkey-tools"
else
    PLIW_MONKEY_DIR="$(cd "${PROJECT_DIR}/.." && pwd)/Pliw-App/monkey-tools"
fi
mkdir -p "${PLIW_MONKEY_DIR}"

DMG_TMP="$(mktemp -d)"
trap 'rm -rf "${DMG_TMP}"' EXIT
DMG_OUTPUT="${PLIW_MONKEY_DIR}/monkey-tools-Installer.dmg"
ZIP_OUTPUT="${PLIW_MONKEY_DIR}/monkey-tools.zip"

echo "📦 Preparing DMG installer directory structure..."
mkdir -p "${DMG_TMP}"

# Copy the .app bundle
cp -R "${PROJECT_DIR}/monkey-tools.app" "${DMG_TMP}/monkey-tools.app"

# Create symlink to /Applications
ln -s /Applications "${DMG_TMP}/Applications"

# Add a ReadMe text inside DMG
cat << 'EOF' > "${DMG_TMP}/How to Install.txt"
===================================================
  🐵 monkey-tools - Windows-Style Clipboard for Mac
===================================================

1. INSTALLATION:
   Drag "monkey-tools.app" into the "Applications" shortcut icon.

2. FIRST-TIME OPEN (macOS Gatekeeper Warning / ความปลอดภัย):
   If macOS warns "cannot be opened because the developer cannot be verified"
   or blocks the app on other Macs:
   - Option A: Open System Settings > Privacy & Security, scroll down to
     "Security", and click "Open Anyway".
   - Option B: In Terminal, run:
     xattr -cr /Applications/monkey-tools.app
   (This only unblocks monkey-tools and does not compromise system security).

3. USAGE:
   - Press your shortcut (default: Command + Shift + V) anywhere to open history.
   - Or click the 📋 icon on the top Menu Bar.

4. CUSTOMIZE SHORTCUT:
   - Click the gear icon (⚙️) or right-click the Menu Bar icon -> "Settings...".
   - You can choose presets (e.g. Option + V like Win+V) or record your own custom keys!

5. AUTO-PASTE & ACCESSIBILITY PERMISSION:
   - In System Settings > Privacy & Security > Accessibility,
     enable monkey-tools to allow instant auto-pasting and global hotkeys.
===================================================
EOF

echo "📀 Creating DMG disk image: ${DMG_OUTPUT}..."
rm -f "${DMG_OUTPUT}"
rm -f "${PROJECT_DIR}/monkey-tools-Installer.dmg"
rm -f "${PROJECT_DIR}/monkey-copy-Installer.dmg"
rm -f "${PROJECT_DIR}/bxxs-clipboard-Installer.dmg"
rm -f "${PROJECT_DIR}/MacClipboard-Installer.dmg"
hdiutil create -volname "monkey-tools Installer" -srcfolder "${DMG_TMP}" -ov -format UDZO "${DMG_OUTPUT}"

echo "🗜️ Creating ZIP archive for in-app updates: ${ZIP_OUTPUT}..."
rm -f "${ZIP_OUTPUT}" "${PROJECT_DIR}/monkey-tools.zip"
ditto -c -k --keepParent "${PROJECT_DIR}/monkey-tools.app" "${ZIP_OUTPUT}"

# Remove temporary local .app bundle so build outputs stay only in public/
rm -rf "${PROJECT_DIR}/monkey-tools.app"

echo "🎉 DMG and ZIP packages successfully created in ${PLIW_MONKEY_DIR}!"
ls -lh "${DMG_OUTPUT}" "${ZIP_OUTPUT}"
