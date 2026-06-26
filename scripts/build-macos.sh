#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="Codex健康值"
BUNDLE_NAME="CodexUsageStatus.app"
BUILD_DIR="$ROOT_DIR/macos/build"
APP_DIR="$BUILD_DIR/$BUNDLE_NAME"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
SERVER_DIR="$RESOURCES_DIR/status-server"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$SERVER_DIR/public"

clang -fobjc-arc -framework Cocoa \
  "$ROOT_DIR/macos/Sources/CodexUsageStatus.m" \
  -o "$MACOS_DIR/CodexUsageStatus"

cp "$ROOT_DIR/server.js" "$SERVER_DIR/server.js"
cp "$ROOT_DIR/package.json" "$SERVER_DIR/package.json"
cp "$ROOT_DIR/public/index.html" "$SERVER_DIR/public/index.html"
cp "$ROOT_DIR/assets/CodexUsageStatus.icns" "$RESOURCES_DIR/CodexUsageStatus.icns"

cat > "$CONTENTS_DIR/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDisplayName</key>
  <string>$APP_NAME</string>
  <key>CFBundleExecutable</key>
  <string>CodexUsageStatus</string>
  <key>CFBundleIconFile</key>
  <string>CodexUsageStatus</string>
  <key>CFBundleIdentifier</key>
  <string>local.codex.usage-status</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>0.1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>LSUIElement</key>
  <true/>
</dict>
</plist>
PLIST

echo "Built $APP_DIR"
