#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/KashTasks.app"
BIN_NAME="KashTasks"
BUNDLE_ID="com.kashish.kashtasks"

echo "Building release binary..."
swift build -c release --package-path "$ROOT"
BIN_PATH="$(swift build -c release --package-path "$ROOT" --show-bin-path)/$BIN_NAME"

echo "Assembling $APP ..."
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"
cp "$BIN_PATH" "$APP/Contents/MacOS/$BIN_NAME"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>KashTasks</string>
    <key>CFBundleDisplayName</key><string>KashTasks</string>
    <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
    <key>CFBundleVersion</key><string>2.0</string>
    <key>CFBundleShortVersionString</key><string>2.0</string>
    <key>CFBundleExecutable</key><string>$BIN_NAME</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>LSUIElement</key><true/>
</dict>
</plist>
PLIST

echo "Ad-hoc signing..."
codesign --force --deep --sign - "$APP"

echo "Done: $APP"
echo "Move it to /Applications and open it, then approve notifications when prompted."
