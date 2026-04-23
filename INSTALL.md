# Installing Pixel Veil

## Quick install

1. Download `PixelVeil-1.0.0.dmg` from the [Releases page](https://github.com/pixelveilteam-dev/pixel-veil/releases).
2. Open the DMG.
3. Drag **Pixel Veil** into **Applications**.
4. Open Pixel Veil from Launchpad or Applications.

## First-launch warning (Gatekeeper)

Because Pixel Veil isn't signed with a paid Apple Developer ID, macOS Gatekeeper will show one of these on first launch:

> `"Pixel Veil" can't be opened because Apple cannot check it for malicious software.`

or

> `"Pixel Veil" is damaged and can't be opened.`

This is expected for any open-source Mac app distributed outside the App Store without a $99/year developer subscription. The source is public — you can audit it in this repo. To bypass the warning, pick one of:

### Option 1: Right-click → Open (easiest)

1. Open **Applications** in Finder.
2. **Right-click** (or Control-click) **Pixel Veil.app**.
3. Choose **Open** from the menu.
4. Click **Open** in the dialog that appears.

You only have to do this once. After that, Pixel Veil launches normally.

### Option 2: System Settings → Privacy & Security

1. Try to open Pixel Veil from Launchpad (it will be blocked).
2. Go to **System Settings → Privacy & Security**.
3. Scroll down. You'll see "Pixel Veil was blocked to protect your Mac."
4. Click **Open Anyway** and confirm.

### Option 3: Terminal (power users)

Remove the quarantine attribute that Safari/Chrome added when you downloaded the DMG:

```bash
xattr -cr /Applications/Pixel\ Veil.app
```

## What Pixel Veil needs

| Permission | Required? | Why |
|-|-|-|
| Accessibility | Optional | More reliable frontmost-app detection in secure-input contexts (e.g. password fields). Used by app rules. |
| Screen Recording | Optional | Reserved for a future Adaptive Text mode that shifts the overlay around detected text regions. |

Neither is required for the basic privacy overlay.

## Uninstalling

Drag `/Applications/Pixel Veil.app` to the Trash. Preferences are stored in
`~/Library/Preferences/com.pixelveil.app.plist` and can be deleted with:

```bash
defaults delete com.pixelveil.app
rm -rf "$HOME/Library/Application Support/PixelVeil"
```
