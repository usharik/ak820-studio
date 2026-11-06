#!/bin/sh
# Builds AK820 Studio.app (and the ak820ctl CLI) into ./dist.
# SwiftUI macros (@State) need the full Xcode toolchain, not only Command Line Tools.
set -e
cd "$(dirname "$0")/.."

if [ -z "$DEVELOPER_DIR" ] && [ -d /Applications/Xcode.app ]; then
    export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi

swift build -c release --arch arm64 --arch x86_64
BIN=$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)

APP="dist/AK820 Studio.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN/AK820Studio" "$APP/Contents/MacOS/AK820Studio"
cp "$BIN/ak820ctl" dist/ak820ctl

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>AK820 Studio</string>
    <key>CFBundleDisplayName</key><string>AK820 Studio</string>
    <key>CFBundleIdentifier</key><string>local.ak820studio</string>
    <key>CFBundleExecutable</key><string>AK820Studio</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>0.1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSApplicationCategoryType</key><string>public.app-category.utilities</string>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

codesign --force --sign - "$APP" dist/ak820ctl
echo "Готово: $APP"
echo "Установка: cp -R \"$APP\" /Applications/"
