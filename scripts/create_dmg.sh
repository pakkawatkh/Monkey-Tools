#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${PROJECT_DIR}"

echo "🔨 Ensuring latest release build of monkey-tools.app..."
./scripts/build_app.sh

DMG_TMP="${PROJECT_DIR}/.build_dmg"
DMG_OUTPUT="${PROJECT_DIR}/monkey-tools-Installer.dmg"

echo "📦 Preparing DMG installer directory structure..."
rm -rf "${DMG_TMP}"
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

2. USAGE:
   - Press your shortcut (default: Command + Shift + V) anywhere to open history.
   - Or click the 📋 icon on the top Menu Bar.

3. CUSTOMIZE SHORTCUT:
   - Click the gear icon (⚙️) or right-click the Menu Bar icon -> "Settings...".
   - You can choose presets (e.g. Option + V like Win+V) or record your own custom keys!

4. AUTO-PASTE PERMISSION:
   - In System Settings > Privacy & Security > Accessibility,
     enable monkey-tools to allow instant auto-pasting when selecting an item.
===================================================
EOF

echo "📀 Creating DMG disk image: ${DMG_OUTPUT}..."
rm -f "${DMG_OUTPUT}"
rm -f "${PROJECT_DIR}/monkey-copy-Installer.dmg"
rm -f "${PROJECT_DIR}/bxxs-clipboard-Installer.dmg"
rm -f "${PROJECT_DIR}/MacClipboard-Installer.dmg"
hdiutil create -volname "monkey-tools Installer" -srcfolder "${DMG_TMP}" -ov -format UDZO "${DMG_OUTPUT}"

# Clean up temporary staging directory
rm -rf "${DMG_TMP}"

echo "🎉 DMG Installer successfully created!"
ls -lh "${DMG_OUTPUT}"
