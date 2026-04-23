#!/bin/bash
# make-dmg.sh — build the app, sign it, and package a pretty DMG with a
# drag-to-Applications UI.
#
# Requirements: Command Line Tools (hdiutil, osascript, sips, swift).
# Produces: ./dist/PixelVeil-<version>.dmg
set -eo pipefail
cd "$(dirname "$0")"

VERSION="1.0.0"
DIST="dist"
DMG_NAME="PixelVeil-${VERSION}"
VOL_NAME="Pixel Veil"
APP="PixelVeil.app"
STAGING="${DIST}/stage"
BG_DIR="${STAGING}/.background"
BG_PNG="${BG_DIR}/background.png"
RW_DMG="${DIST}/${DMG_NAME}-rw.dmg"
FINAL_DMG="${DIST}/${DMG_NAME}.dmg"

# 1. Build the signed .app.
echo "[1/6] Building app…"
bash build-app.sh >/dev/null

# 2. Fresh dist directory.
echo "[2/6] Preparing dist…"
rm -rf "$DIST"
mkdir -p "$STAGING" "$BG_DIR"

# 3. Generate the DMG background.
echo "[3/6] Rendering background…"
swift tools/make-dmg-background.swift \
    "PixelVeil/Resources/Images/logo-mark.png" \
    "$BG_PNG"

# 4. Copy app, create Applications symlink.
echo "[4/6] Assembling staging…"
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

# 5. Create a read-write DMG from the staging folder, mount it, apply window
#    settings via AppleScript, then unmount.
echo "[5/6] Creating writable DMG and styling…"
rm -f "$RW_DMG"
hdiutil create \
    -srcfolder "$STAGING" \
    -volname "$VOL_NAME" \
    -fs HFS+ \
    -fsargs "-c c=64,a=16,e=16" \
    -format UDRW \
    -size 120m \
    "$RW_DMG" >/dev/null

MOUNT_DIR="/Volumes/${VOL_NAME}"
hdiutil attach "$RW_DMG" -mountpoint "$MOUNT_DIR" -nobrowse -noautoopen >/dev/null

# Give the Finder a moment to notice the volume.
sleep 1

# Apply Finder styling via AppleScript. Window opens at 640x400 (matching
# the background image), icon size 96px, specific positions for the app and
# Applications alias.
osascript <<OSAEOF
tell application "Finder"
    tell disk "$VOL_NAME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {200, 200, 840, 600}
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 96
        set text size of viewOptions to 12
        set background picture of viewOptions to file ".background:background.png"
        set position of item "$APP" of container window to {160, 200}
        set position of item "Applications" of container window to {480, 200}
        update without registering applications
        close
    end tell
end tell
OSAEOF

# Let Finder flush its state.
sleep 2
sync
hdiutil detach "$MOUNT_DIR" >/dev/null || hdiutil detach "$MOUNT_DIR" -force >/dev/null

# 6. Convert to compressed read-only DMG.
echo "[6/6] Converting to compressed DMG…"
rm -f "$FINAL_DMG"
hdiutil convert "$RW_DMG" -format UDZO -imagekey zlib-level=9 -o "$FINAL_DMG" >/dev/null
rm -f "$RW_DMG"

# Ad-hoc sign the DMG itself. Same caveat as the app: no Developer ID =
# users still see Gatekeeper on first mount, but integrity is checksummed.
codesign --force --sign - "$FINAL_DMG" >/dev/null 2>&1 || true

SIZE=$(du -h "$FINAL_DMG" | cut -f1)
echo
echo "✔ Done: $FINAL_DMG ($SIZE)"
