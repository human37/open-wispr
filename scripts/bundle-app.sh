#!/bin/bash
set -euo pipefail

BINARY="${1:-.build/release/open-wispr}"
APP_DIR="${2:-OpenWispr.app}"
VERSION="${3:-0.3.0}"

select_codesign_identity() {
    if [ -n "${OPEN_WISPR_CODESIGN_IDENTITY:-}" ]; then
        echo "$OPEN_WISPR_CODESIGN_IDENTITY"
        return
    fi

    security find-identity -v -p codesigning 2>/dev/null \
        | sed -n 's/^[[:space:]]*[0-9][0-9]*)[[:space:]]*[0-9A-F]*[[:space:]]*"\(Apple Development:.*\)"$/\1/p' \
        | head -1
}

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

cp "$BINARY" "$APP_DIR/Contents/MacOS/open-wispr"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cp "$REPO_DIR/Resources/AppIcon.icns" "$APP_DIR/Contents/Resources/AppIcon.icns"

cat > "$APP_DIR/Contents/Info.plist" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>open-wispr</string>
    <key>CFBundleIdentifier</key>
    <string>com.human37.open-wispr</string>
    <key>CFBundleName</key>
    <string>OpenWispr</string>
    <key>CFBundleDisplayName</key>
    <string>OpenWispr</string>
    <key>CFBundleVersion</key>
    <string>${VERSION}</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSMicrophoneUsageDescription</key>
    <string>OpenWispr needs microphone access to record speech for transcription.</string>
    <key>NSAudioCaptureUsageDescription</key>
    <string>OpenWispr needs system audio access to transcribe meetings locally.</string>
</dict>
</plist>
PLIST

SIGN_IDENTITY="$(select_codesign_identity)"
if [ -n "$SIGN_IDENTITY" ]; then
    echo "Signing with identity: $SIGN_IDENTITY"
    codesign --force --sign "$SIGN_IDENTITY" --identifier com.human37.open-wispr --timestamp=none "$APP_DIR"
else
    echo "Signing with ad-hoc identity"
    codesign --force --sign - --identifier com.human37.open-wispr "$APP_DIR"
fi

echo "Built $APP_DIR"
