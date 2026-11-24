#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${PROJECT_DIR}"

# Prefer full Xcode toolchain when installed (CommandLineTools lacks SwiftUIMacros plugin on newer macOS SDKs)
if [ -z "${DEVELOPER_DIR}" ] && [ -d "/Applications/Xcode.app/Contents/Developer" ]; then
    export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
fi

echo "🔨 Building monkey-tools (Release mode)..."
swift build -c release -Xswiftc -cross-module-optimization

RELEASE_BIN="${PROJECT_DIR}/.build/release/monkey-tools"
APP_DIR="${PROJECT_DIR}/monkey-tools.app"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

echo "📦 Assembling monkey-tools.app bundle..."
rm -rf "${APP_DIR}"
mkdir -p "${MACOS_DIR}"
mkdir -p "${RESOURCES_DIR}"

cp "${RELEASE_BIN}" "${MACOS_DIR}/monkey-tools"
strip "${MACOS_DIR}/monkey-tools"
chmod +x "${MACOS_DIR}/monkey-tools"

if [ -d "${PROJECT_DIR}/Resources" ]; then
    cp -R "${PROJECT_DIR}/Resources/"* "${RESOURCES_DIR}/" || true
fi

cat << 'EOF' > "${CONTENTS_DIR}/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>monkey-tools</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.local.monkey-tools</string>
    <key>CFBundleName</key>
    <string>monkey-tools</string>
    <key>CFBundleDisplayName</key>
    <string>monkey-tools</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>2.3.2</string>
    <key>CFBundleVersion</key>
    <string>2.3.2</string>
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
# Check if MonkeyToolsDeveloper or MonkeyCopyDeveloper cert is in keychain, create if not
SIGN_CERT="MonkeyToolsDeveloper"
if ! security find-certificate -c "${SIGN_CERT}" ~/Library/Keychains/login.keychain-db >/dev/null 2>&1; then
    if security find-certificate -c "MonkeyCopyDeveloper" ~/Library/Keychains/login.keychain-db >/dev/null 2>&1; then
        SIGN_CERT="MonkeyCopyDeveloper"
    else
        echo "Creating persistent local developer certificate for stable macOS TCC permissions..."
        TMP_CERT_DIR=$(mktemp -d)
        openssl req -x509 -newkey rsa:2048 -days 3650 \
          -keyout "${TMP_CERT_DIR}/dev.key" -out "${TMP_CERT_DIR}/dev.crt" -nodes \
          -subj "/CN=MonkeyToolsDeveloper" \
          -addext "keyUsage=critical,digitalSignature" \
          -addext "extendedKeyUsage=codeSigning"
        openssl pkcs12 -export \
          -in "${TMP_CERT_DIR}/dev.crt" -inkey "${TMP_CERT_DIR}/dev.key" \
          -out "${TMP_CERT_DIR}/dev.p12" -password pass:monkeytools
        security import "${TMP_CERT_DIR}/dev.p12" -k ~/Library/Keychains/login.keychain-db -P monkeytools -T /usr/bin/codesign || true
        rm -rf "${TMP_CERT_DIR}"
    fi
fi

codesign --force --deep --sign "${SIGN_CERT}" "${APP_DIR}" || codesign --force --deep --sign - "${APP_DIR}"

echo "✅ Successfully built: ${APP_DIR}"

# Update /Applications/monkey-tools.app if not skipped
if [ -z "${SKIP_INSTALL}" ]; then
    echo "📲 Updating /Applications/monkey-tools.app..."
    pkill -9 -f monkey-tools || true
    pkill -9 -f monkey-copy || true
    pkill -9 -f bxxs-clipboard || true
    pkill -9 -f MacClipboard || true
    rm -rf "/Applications/monkey-tools.app"
    rm -rf "/Applications/monkey-copy.app"
    rm -rf "/Applications/bxxs-clipboard.app"
    rm -rf "/Applications/MacClipboard.app"
    cp -R "${APP_DIR}" "/Applications/monkey-tools.app"
    echo "🎉 Updated /Applications/monkey-tools.app"
else
    echo "⏭️ Skipping install to /Applications because SKIP_INSTALL is set."
fi
