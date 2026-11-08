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
cp -R Localization/*.lproj "$APP/Contents/Resources/"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"   # regenerate with: swift scripts/make-icon.swift
LOCALIZATIONS=$(for d in Localization/*.lproj; do printf '<string>%s</string>' "$(basename "$d" .lproj)"; done)

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key><string>en</string>
    <key>CFBundleLocalizations</key><array>$LOCALIZATIONS</array>
    <key>CFBundleName</key><string>AK820 Studio</string>
    <key>CFBundleDisplayName</key><string>AK820 Studio</string>
    <key>CFBundleIdentifier</key><string>local.ak820studio</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundleExecutable</key><string>AK820Studio</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>0.1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSApplicationCategoryType</key><string>public.app-category.utilities</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSAudioCaptureUsageDescription</key><string>Music mode listens to the system audio to light up the keyboard like an equalizer. Audio is analyzed on this Mac and never stored.</string>
</dict>
</plist>
PLIST

codesign --force --sign - "$APP" dist/ak820ctl
echo "Built: $APP"
echo "Install: cp -R \"$APP\" /Applications/"
