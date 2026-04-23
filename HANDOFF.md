# Pixel Veil — Session Handoff

This document is written for **a future AI coding assistant** continuing work on
Pixel Veil. A human reader can use it too, but the tone is deliberately
tactical: what exists, where it is, why it was built that way, and what
traps to avoid. Read this first before touching anything.

> **Current version:** see [`VERSION`](./VERSION). Update there and the build
> scripts, `Info.plist`, and DMG filename all pick it up automatically.

---

## 1. Project map

Two GitHub repos under the `pixelveilteam-dev` org — both public:

| Repo | Local path | Purpose |
|-|-|-|
| `pixel-veil` | `/Users/28atotten/PixelVeil` | The macOS app (SwiftUI + AppKit + Metal). |
| `pixel-veil-website` | `/Users/28atotten/pixel-veil-website` | Static marketing site hosted on GitHub Pages. |

> **Naming history:** Both repos were originally named `pixel-view` (typo). User
> renamed to `pixel-veil` on 2026-04-23. Any residual `pixel-view` references
> in the codebase should be treated as bugs and fixed on sight.

## 2. Architecture (app)

```
PixelVeil/
├── App/                 PixelVeilApp.swift (@main) + AppDelegate.swift
├── Core/
│   ├── Automation/      AppRuleEngine, ScheduleEngine
│   ├── Displays/        DisplayManager, BrightnessController
│   ├── Hotkeys/         HotkeyManager (Carbon RegisterEventHotKey)
│   ├── MenuBar/         MenuBarController (NSStatusItem + popover)
│   ├── Overlay/         OverlayController, OverlayWindow, MetalPatternView, PatternRenderer
│   ├── Permissions/     PermissionsManager
│   └── Settings/        SettingsStore (@Published + debounced persistence), PreferencesModel
├── Shaders/             MetalPatternShaders.swift (source embedded in Swift string, compiled at runtime via MTLDevice.makeLibrary(source:))
├── UI/                  SwiftUI — RootView, Sidebar, Sections, Components, FirstRunView
├── Resources/           Info.plist, entitlements, Images/ (logo PNGs + AppIcon.icns)
├── tools/               make-dmg-background.swift
├── Package.swift        SwiftPM executable target (macOS 13+, links Carbon)
├── build-app.sh         swift build + wrap into .app + sign
├── make-dmg.sh          build-app.sh + stage + AppleScript + hdiutil → .dmg
├── VERSION              Single source of truth for version string
├── CHANGELOG.md         Keep-a-Changelog format
├── INSTALL.md           User-facing install + Gatekeeper bypass
└── HANDOFF.md           This file
```

### Data flow

```
SettingsStore ──▶ OverlayController ──▶ OverlayWindow (per display)
   ▲                 ▲                        │
   │                 │                        ▼
  UI     ScheduleEngine                MetalPatternView
         AppRuleEngine                 (GPU fragment shader)
         BrightnessController
         HotkeyManager
```

`SettingsStore` is the single source of truth. Everything else reacts.
Automation engines publish `forcedOn` / `forcedOff` overrides on
`OverlayController` — **they never write to `settings.isEnabled` directly**.
This preserves user intent.

### Overlay engine

- `OverlayWindow` — borderless, transparent, click-through, level =
  `CGWindowLevelForKey(.screenSaverWindow)`. Screen-saver level is the **only**
  level that reliably honours `canJoinAllSpaces`; lower levels (tried
  `.popUpMenu`) are Space-local.
- `MetalPatternView` — MTKView at `isPaused = true` +
  `enableSetNeedsDisplay = true`, so it only renders when a preference
  changes. Idle GPU cost is zero.
- Shader: one full-screen triangle, fragment stage produces a mid-grey
  contrast-reduction veil plus a per-mode pattern. See
  `Shaders/MetalPatternShaders.swift`.

### The `@Published` willSet gotcha — critical

`@Published` emits **in `willSet`**, before the stored property updates. A
Combine sink that reads the object's property synchronously sees the *old*
value. This bit us once (the "Active dims but no pattern / Inactive shows
the pattern" bug).

**Rule:** any sink that reads `@Published` properties from the same
ObservableObject via property-access (rather than from the tuple value
passed into the closure) **must** hop to the next runloop tick via
`DispatchQueue.main.async`. See `OverlayController.bind()`,
`AppRuleEngine.bind()`, `ScheduleEngine.bind()`.

### Gatekeeper reality

macOS requires an Apple Developer ID ($99/yr) + Apple notarization to silence
Gatekeeper. We do **not** have that. Current `build-app.sh` ad-hoc signs with
`--options runtime` and the entitlements file — the strongest possible
signature from Command Line Tools. Users see a one-time "cannot verify
developer" dialog on first launch. `INSTALL.md` documents three bypass paths.

If a Developer ID becomes available, change the `--sign -` arg in
`build-app.sh` to `--sign "Developer ID Application: Your Name (TEAMID)"` and
add `xcrun notarytool submit` + `xcrun stapler staple` after. No other code
changes needed.

### Private API usage

`BrightnessController` `dlopen`'s `/System/Library/PrivateFrameworks/DisplayServices.framework`
and `dlsym`'s:

- `DisplayServicesGetBrightness(CGDirectDisplayID, *Float) -> Int32`
- `DisplayServicesSetBrightness(CGDirectDisplayID, Float) -> Int32`
- `DisplayServicesGetAutoBrightnessIsEnabled` / `IsAutoBrightnessEnabled` (probes both names)
- `DisplayServicesSetAutoBrightnessIsEnabled` / `SetAutoBrightness` (probes both)

All failures are silent — the controller no-ops if symbols move. Same
technique used by the `brightness` CLI, Lunar, and MonitorControl. Not App
Store friendly (private API), but the app isn't App Store bound.

## 3. Build & release workflow

### Local dev

```bash
bash build-app.sh              # → PixelVeil.app (ad-hoc signed)
open PixelVeil.app             # launch
pkill -f PixelVeil             # stop
```

### Producing a distribution DMG

```bash
bash make-dmg.sh               # → dist/PixelVeil-<VERSION>.dmg
```

The DMG:
- Contains `PixelVeil.app` + `Applications` symlink
- 640×400 Finder window, 96 px icons at `(160,200)` and `(480,200)`
- Custom background rendered by `tools/make-dmg-background.swift`
  (CoreGraphics — gradient, centred logo, drag-to-install arrow)
- Applied via AppleScript during the rw phase, then converted to UDZO

### Bumping the version

1. Edit `VERSION` (e.g. `1.0.0` → `1.1.0`).
2. Update `CHANGELOG.md` under `[Unreleased]` → move entries to the new
   version header, add date.
3. `bash make-dmg.sh` — produces `dist/PixelVeil-1.1.0.dmg`.
4. Commit: `git commit -m "Bump to v1.1.0"`.
5. Tag: `git tag v1.1.0 && git push origin v1.1.0`.
6. Create release (see §5 for the push workflow with tokens):
   ```bash
   gh release create v1.1.0 \
     --repo pixelveilteam-dev/pixel-veil \
     --title "Pixel Veil 1.1.0" \
     --notes-file CHANGELOG.md \
     dist/PixelVeil-1.1.0.dmg
   ```
7. The website auto-updates via the GitHub releases API — no website
   change required.

### Test checklist before cutting a release

- [ ] App launches
- [ ] Toggle flips overlay on/off instantly (no "one-click lag")
- [ ] Brightness drops on activate, restores on deactivate
- [ ] Works across Space swipes (the tell is a window disappearing on the
      new desktop — if that happens the `.canJoinAllSpaces` behaviour is
      broken; see §2 "Overlay engine" for the level requirement)
- [ ] Menu bar glyph shows filled-active / hollow-inactive
- [ ] Global hotkey works from any app
- [ ] Per-display override takes effect on second monitor
- [ ] App rule activates overlay when matching app becomes frontmost
- [ ] Quit restores brightness (even if force-quit via ⌘Q)

## 4. Website (`pixel-veil-website`)

Plain HTML + CSS + vanilla JS — no framework, no build step. GitHub Pages
serves from `main` / `/` (root). Files:

- `index.html` — sections: hero, features, how-it-works, preview, quotes,
  FAQ, download, community, footer.
- `styles.css` — hand-rolled; dark theme, `Inter` + `JetBrains Mono` from
  Google Fonts; animations described inline at the top of the file.
- `scripts.js` — letter-by-letter hero reveal, mouse-tracked cursor glow,
  3D tilt on `[data-tilt]`, magnetic buttons, scroll progress bar,
  feature-card spotlight, staggered reveal-on-scroll, **GitHub releases
  API release detection** (auto-updates download URL and version/size
  labels to the latest release — falls back to hardcoded v1.0.0 if the
  API is unreachable).
- `assets/` — logo PNGs + onboarding illustrations copied from the app
  repo's `Resources/Images/`.

### Discord

Central constant `DISCORD_INVITE` in `scripts.js`. Every
`[data-discord-link]` element is rewritten to that URL. Current invite:
`https://discord.gg/mkuukjwXPB`.

### GitHub Pages

Enable at Settings → Pages → Source = `main` / `/ (root)`. Published at
`https://pixelveilteam-dev.github.io/pixel-veil-website/`. No build step
involved — push to `main` triggers a Pages rebuild within ~45 s.

## 5. Git / push workflow (CRITICAL)

### Authentication

The user does **not** maintain write access under the assistant's default
`gh` identity (`spooftrap-app`). They issue **fine-grained PATs** scoped to
`pixelveilteam-dev/pixel-veil` and `pixel-veil-website` with
`Contents: Read and write`.

**Never** write a PAT to:
- `.git/config`
- macOS keychain
- any file that gets committed
- chat transcript (treat as already-burnt if it appears)

### One-shot push pattern

```bash
PAT="$(tr -d '\n\r \t' < /Users/28atotten/PixelVeil/token-pixel.txt)"
cd /Users/28atotten/PixelVeil    # or pixel-veil-website
git -c credential.helper= push \
    "https://x-access-token:${PAT}@github.com/pixelveilteam-dev/pixel-veil.git" main:main
unset PAT
```

Points:
- `-c credential.helper=` disables credential caching for the single
  invocation.
- Token lives inline in the URL for *this command only* — `git remote -v`
  should still show the clean URL (no embedded token) after.
- `x-access-token` as the username is the GitHub convention for PATs.

### Token file lifecycle (updated 2026-04-23)

The user keeps `/Users/28atotten/PixelVeil/token-pixel.txt` around between
pushes. **Do NOT auto-delete it** after every push. Rotate (delete locally
+ revoke + re-issue on GitHub) only:
- every ~10 pushes, as a hygiene rhythm
- or immediately if the raw token string has leaked to a chat transcript,
  a log, or any committed file
- or when the user explicitly asks

If TextEdit was used to save the file: user needs to convert to plain
text first (`Format → Make Plain Text`) or the file is an RTF with
formatting — use `textutil -convert txt -stdout FILE.rtf` to extract the
real string.

### What pushes go to

| Action | Repo | Command shape |
|-|-|-|
| Code commits | `pixelveilteam-dev/pixel-veil` | `git push origin main` |
| Website commits | `pixelveilteam-dev/pixel-veil-website` | `git push origin main` |
| Releases | `pixelveilteam-dev/pixel-veil` | `gh release create vX.Y.Z … dist/*.dmg` |

### GitHub Pages enable (one-time)

Can be done via API with the PAT:
```bash
GH_TOKEN="${PAT}" gh api --method POST \
    /repos/pixelveilteam-dev/pixel-veil-website/pages \
    -f 'source[branch]=main' -f 'source[path]=/'
```
Or user does it manually in the repo settings.

## 6. Assets inventory

All in `PixelVeil/Resources/Images/`:

| File | Source | Used by |
|-|-|-|
| `logo-mark.png` | User-provided standalone mark | Sidebar header, About, First-Run, menu bar, DMG background, website nav |
| `logo-full.png` | User-provided logo with wordmark, white bg | Reserve / Open Graph social image |
| `logo-transparent.png` | User-provided logo with wordmark, transparent | Dock icon via `NSApplication.applicationIconImage` |
| `onboard-welcome.png` | User-provided illustration (monitor + silhouettes) | First-Run welcome page, website preview section |
| `onboard-how.png` | User-provided illustration (flow diagram) | First-Run "How it works" page, website how section |
| `AppIcon.icns` | Generated via `sips` + `iconutil` from `logo-mark.png` | `CFBundleIconFile` so Dock/Launchpad/Finder see the icon pre-launch |

`AppIcon.icns` is committed. To regenerate:
```bash
cd /Users/28atotten/PixelVeil
mkdir AppIcon.iconset
for s in 16 32 128 256 512; do
  sips -z $s $s PixelVeil/Resources/Images/logo-mark.png \
    --out AppIcon.iconset/icon_${s}x${s}.png
  sips -z $((s*2)) $((s*2)) PixelVeil/Resources/Images/logo-mark.png \
    --out AppIcon.iconset/icon_${s}x${s}@2x.png
done
iconutil -c icns AppIcon.iconset -o PixelVeil/Resources/Images/AppIcon.icns
rm -rf AppIcon.iconset
```

## 7. Things that look like bugs but aren't

- **The overlay covers Pixel Veil's own window.** Intentional — at screen-saver
  level the overlay composits over everything. User specifically wants this
  so they can see what side-viewers see. Don't change window level without
  also fixing cross-Space behaviour (lower levels break `canJoinAllSpaces`).
- **The live-preview wallpaper is muted on purpose.** User asked for
  "macOS 26 vibes — low-key". Don't punch up the saturation.
- **The menu-bar glyph is a template 3×3 grid, not the logo.** User
  preferred this after briefly trying a colour-filled logo icon in the
  menu bar. Don't swap without asking.
- **`memory/` exists locally but is `.gitignore`d.** Assistant scratch
  notes, not source.
- **Swift warnings about "unhandled resources" during `swift build`.** The
  PNG/`.icns` files in `Resources/Images/` aren't declared as SwiftPM
  resources because we copy them into the `.app` bundle via `build-app.sh`
  instead. The warning is benign.

## 8. Known unsolved problems

- **Notarization.** Blocked on acquiring an Apple Developer ID.
- **System UI coverage.** Screen-saver-level windows don't sit above
  Control Center, the screenshot toolbar, or Mission Control. There is
  no user-space workaround.
- **True directional privacy.** Software can't narrow an LCD's viewing
  cone. Our contrast-reduction approach is the best approximation but
  isn't equivalent to a hardware privacy panel. Gaze-locked masking via
  FaceTime camera + Vision `VNFaceObservation` was discussed; it's
  doable in ~200 lines but not yet built.
- **Assets.xcassets is never compiled** (no Xcode). Accent color falls
  back to system accent. Not a problem in practice; future migration to
  full Xcode would fix it.

## 9. Things to never do without explicit user approval

- Force-push `main` on either repo.
- Commit or transmit a PAT anywhere beyond the one-shot push.
- Make either repo private (user chose public to enable GitHub Pages + to
  build public trust for a privacy tool).
- Remove `INSTALL.md`'s Gatekeeper bypass instructions — users need them
  and will churn without them.
- Skip hooks / sign with `--no-verify` on commits.
- Change the overlay window level from `.screenSaverWindow` (it will
  break cross-Space).

## 10. Contact & context

- User: Abderrahmane Totten (`abdudepostio@gmail.com`, git identity).
- Communication style: direct, short responses preferred. User flags
  issues fast; resolve decisively rather than asking five follow-up
  questions.
- User doesn't have Xcode installed. Only Command Line Tools + Swift 5.10.
  Keep the build pipeline toolchain-minimal.

Good luck. The hardest parts (the `@Published` timing bug, cross-Space
overlay, the ad-hoc sign + DMG pipeline) are already solved. Keep them
solved.
