#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"

APP_NAME="Parcelite"
BUNDLE_ID="com.oliwer.parcelite"
VERSION="${VERSION:-0.1.0}"
DEST="${1:-dist}"
APP="$DEST/$APP_NAME.app"
ZIP="$DEST/$APP_NAME-$VERSION-macOS.zip"

swift build -c release --product "$APP_NAME"

rm -rf "$APP" "$ZIP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp ".build/release/$APP_NAME" "$APP/Contents/MacOS/$APP_NAME"

if [ ! -f "AppIcon.icns" ]; then
    echo "Generating AppIcon.icns..."
    rm -rf AppIcon.iconset
    swift make-icon.swift AppIcon.iconset
    iconutil -c icns AppIcon.iconset -o AppIcon.icns
    rm -rf AppIcon.iconset
fi
cp AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>$APP_NAME</string>
    <key>CFBundleDisplayName</key><string>$APP_NAME</string>
    <key>CFBundleExecutable</key><string>$APP_NAME</string>
    <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
    <key>CFBundleVersion</key><string>$VERSION</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSPrincipalClass</key><string>NSApplication</string>
</dict>
</plist>
PLIST

codesign --force --deep --sign - "$APP" 2>/dev/null || true
touch "$APP"
ditto -c -k --keepParent "$APP" "$ZIP"

echo "Built: $APP"
echo "Archive: $ZIP"
