#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${PROJECT_DIR}"

echo "🔨 Building monkey-copy (Release mode)..."
swift build -c release

RELEASE_BIN="${PROJECT_DIR}/.build/release/monkey-copy"
APP_DIR="${PROJECT_DIR}/monkey-copy.app"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

echo "📦 Assembling monkey-copy.app bundle..."
rm -rf "${APP_DIR}"
mkdir -p "${MACOS_DIR}"
mkdir -p "${RESOURCES_DIR}"

cp "${RELEASE_BIN}" "${MACOS_DIR}/monkey-copy"
chmod +x "${MACOS_DIR}/monkey-copy"

if [ -d "${PROJECT_DIR}/Resources" ]; then
    cp -R "${PROJECT_DIR}/Resources/"* "${RESOURCES_DIR}/" || true
fi

cat << 'EOF' > "${CONTENTS_DIR}/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>monkey-copy</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.local.monkey-copy</string>
    <key>CFBundleName</key>
    <string>monkey-copy</string>
    <key>CFBundleDisplayName</key>
    <string>monkey-copy</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticGraphicsSwitching</key>
    <true/>
</dict>
</plist>
EOF

echo "🔏 Code signing app bundle with stable certificate..."
# Check if MonkeyCopyDeveloper cert is in keychain, create if not
if ! security find-certificate -c "MonkeyCopyDeveloper" ~/Library/Keychains/login.keychain-db >/dev/null 2>&1; then
    echo "Creating persistent local developer certificate for stable macOS TCC permissions..."
    TMP_CERT_DIR=$(mktemp -d)
    openssl req -x509 -newkey rsa:2048 -days 3650 \
      -keyout "${TMP_CERT_DIR}/dev.key" -out "${TMP_CERT_DIR}/dev.crt" -nodes \
      -subj "/CN=MonkeyCopyDeveloper" \
      -addext "keyUsage=critical,digitalSignature" \
      -addext "extendedKeyUsage=codeSigning"
    openssl pkcs12 -export \
      -in "${TMP_CERT_DIR}/dev.crt" -inkey "${TMP_CERT_DIR}/dev.key" \
      -out "${TMP_CERT_DIR}/dev.p12" -password pass:monkeycopy
    security import "${TMP_CERT_DIR}/dev.p12" -k ~/Library/Keychains/login.keychain-db -P monkeycopy -T /usr/bin/codesign || true
    rm -rf "${TMP_CERT_DIR}"
fi

codesign --force --deep --sign "MonkeyCopyDeveloper" "${APP_DIR}" || codesign --force --deep --sign - "${APP_DIR}"

echo "✅ Successfully built: ${APP_DIR}"

# Update /Applications/monkey-copy.app
echo "📲 Updating /Applications/monkey-copy.app..."
pkill -9 -f monkey-copy || true
pkill -9 -f bxxs-clipboard || true
pkill -9 -f MacClipboard || true
rm -rf "/Applications/monkey-copy.app"
rm -rf "/Applications/bxxs-clipboard.app"
rm -rf "/Applications/MacClipboard.app"
cp -R "${APP_DIR}" "/Applications/monkey-copy.app"
echo "🎉 Updated /Applications/monkey-copy.app"
