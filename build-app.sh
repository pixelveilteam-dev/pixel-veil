#!/bin/bash
# build-app.sh — build Pixel Veil and wrap the SwiftPM binary into a .app bundle.
# Command Line Tools only, no Xcode required.
set -eo pipefail

cd "$(dirname "$0")"

# Single source of truth for the version string. Edit VERSION and everything
# downstream (Info.plist, DMG name, release tag) picks it up.
VERSION="$(cat VERSION 2>/dev/null | tr -d '[:space:]')"
: "${VERSION:=1.0.0}"

echo "Building release v${VERSION}..."
swift build -c release

APP="PixelVeil.app"
BIN=".build/release/PixelVeil"

echo "Packaging $APP..."
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"

cp "$BIN" "$APP/Contents/MacOS/PixelVeil"
chmod +x "$APP/Contents/MacOS/PixelVeil"

# Ship the logo PNGs + onboarding illustrations + app icon inside the bundle
# so AppImages.swift can load them with Bundle.main. Using PNGs + a raw
# .icns avoids needing Xcode's asset-catalog compilation.
if [ -d "PixelVeil/Resources/Images" ]; then
    cp PixelVeil/Resources/Images/*.png "$APP/Contents/Resources/" 2>/dev/null || true
    cp PixelVeil/Resources/Images/AppIcon.icns "$APP/Contents/Resources/" 2>/dev/null || true
fi

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key><string>en</string>
    <key>CFBundleDisplayName</key><string>Pixel Veil</string>
    <key>CFBundleExecutable</key><string>PixelVeil</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundleIdentifier</key><string>com.pixelveil.app</string>
    <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
    <key>CFBundleName</key><string>Pixel Veil</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>__VERSION__</string>
    <key>CFBundleVersion</key><string>__VERSION__</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>LSApplicationCategoryType</key><string>public.app-category.utilities</string>
    <key>LSUIElement</key><false/>
    <key>NSHumanReadableCopyright</key><string>(c) 2026 Pixel Veil</string>
    <key>NSPrincipalClass</key><string>NSApplication</string>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

# Substitute the version placeholders we just wrote.
sed -i '' "s/__VERSION__/${VERSION}/g" "$APP/Contents/Info.plist"

# Sign the app. Without an Apple Developer ID ($99/yr) we can't produce a
# Gatekeeper-accepted signature, but an ad-hoc signature with the hardened
# runtime is still the strongest thing possible from Command Line Tools —
# it prevents dylib injection, disables most sandbox escapes, and lets the
# bundle pass the first round of Gatekeeper checks. Users still need to do a
# one-time right-click → Open on first launch (instructions in INSTALL.md).
if [ -f PixelVeil.entitlements ]; then
    ENT="--entitlements PixelVeil.entitlements"
elif [ -f PixelVeil/Resources/PixelVeil.entitlements ]; then
    ENT="--entitlements PixelVeil/Resources/PixelVeil.entitlements"
else
    ENT=""
fi
codesign --force --deep \
    --sign - \
    --options runtime \
    --timestamp=none \
    $ENT \
    "$APP" >/dev/null 2>&1 || true

# Verify: strict validation. If this fails the app will fail to launch on
# locked-down systems — worth flagging even if we continue.
codesign --verify --strict "$APP" 2>&1 | head -5 || true

echo "Done: $PWD/$APP"
