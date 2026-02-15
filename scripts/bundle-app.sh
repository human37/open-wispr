#!/bin/bash
set -euo pipefail

BINARY="${1:-.build/release/open-wispr}"
APP_DIR="${2:-OpenWispr.app}"
VERSION="${3:-0.3.0}"

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

cp "$BINARY" "$APP_DIR/Contents/MacOS/open-wispr"

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
    <key>LSUIElement</key>
    <true/>
    <key>NSMicrophoneUsageDescription</key>
    <string>OpenWispr needs microphone access to record speech for transcription.</string>
</dict>
</plist>
PLIST

codesign --force --sign - --identifier com.human37.open-wispr "$APP_DIR"

echo "Built $APP_DIR"
