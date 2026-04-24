# Pixel Veil

A native macOS privacy-screen utility. Pixel Veil composites a configurable mask
over your displays to reduce side-angle readability — the software analogue of
Samsung's hardware privacy mode.

## Getting it into Xcode

The sources are laid out as an ordinary Xcode project tree, but this scaffold
ships without a generated `.xcodeproj` (pbxprojs are fragile to hand-write).
Create a new Xcode project and drop the sources in:

1. **File → New → Project… → macOS → App**
   - Product Name: `Pixel Veil`
   - Interface: SwiftUI
   - Language: Swift
   - Bundle ID: `com.pixelveil.app`
2. Delete Xcode's generated `ContentView.swift`, `…App.swift`, `Info.plist`,
   `Assets.xcassets`, and the entitlements file.
3. Drag the `PixelVeil/` folder from this repo into the project navigator.
   Choose **Create groups**, target = PixelVeil.
4. In the target settings:
   - **General → Minimum Deployments:** macOS 13.0
   - **Signing & Capabilities → App Sandbox:** OFF (see note below)
   - **Build Settings → Info.plist File:** `PixelVeil/Resources/Info.plist`
   - **Build Settings → Code Signing Entitlements:**
     `PixelVeil/Resources/PixelVeil.entitlements`
5. Make sure `PatternShaders.metal` is a member of the app target (it is
   compiled into the default Metal library automatically).

That's it — ⌘R runs the app.

## Architecture

```
PixelVeil/
├── App/                 App entry + AppDelegate (service wiring)
├── Core/
│   ├── Settings/        Preferences model + UserDefaults-backed store
│   ├── Overlay/         Metal view + transparent NSWindow + controller
│   ├── Displays/        NSScreen tracking, brightness + gamma assist
│   ├── Hotkeys/         Carbon RegisterEventHotKey wrapper
│   ├── Automation/      App-rule + schedule engines
│   ├── Permissions/     Accessibility + Screen Recording status
│   └── MenuBar/         NSStatusItem + popover glue
├── UI/
│   ├── Sidebar/         Source list
│   ├── Sections/        One view per sidebar section
│   ├── Components/      Card, PatternPicker, LivePreview, HotkeyRecorder…
│   └── MenuBar/         SwiftUI popover content
├── Shaders/             PatternShaders.metal — the pattern modes
└── Resources/           Info.plist, Assets, entitlements
```

### Data flow

```
SettingsStore ──▶ OverlayController ──▶ OverlayWindow (per display)
      ▲                 ▲                       │
      │                 │                       ▼
  SwiftUI UI      ScheduleEngine          MetalPatternView
      ▲           AppRuleEngine          (GPU fragment shader)
      │           HotkeyManager
      │
  User actions
```

`SettingsStore` is the single source of truth. Everything that needs to react
to a preference change binds to one of its `@Published` slivers with Combine.
Automation engines never write to the master toggle — they publish
`forcedOn` / `forcedOff` overrides on the controller, so the user's intent is
never silently overwritten.

## How the overlay works

In full-display mode, `OverlayController` creates one borderless `NSWindow` on
each attached display with:

- `level = CGWindowLevelForKey(.screenSaverWindow)` — the highest layer an
  ordinary app can sit at. System UI (Control Center, screenshot toolbar) is
  still above us; everything else is below.
- `collectionBehavior = [canJoinAllSpaces, stationary, fullScreenAuxiliary]` —
  visible on every Space, including over full-screen apps.
- `ignoresMouseEvents = true` — pointer events fall through.
- `backgroundColor = .clear`, `isOpaque = false` — only masked regions
  contribute alpha.

Each window's content view is a `MetalPatternView` (`MTKView`). It uses
`enableSetNeedsDisplay = true` + `isPaused = true`, so it does *not* run at
60 Hz — we only redraw when strength/density/pattern changes. Idle overhead is
essentially zero.

App rules can also target only the visible windows owned by a selected app. In
that mode `WindowTargetProvider` reads WindowServer bounds with
`CGWindowListCopyWindowInfo`, and the overlay creates smaller pass-through
windows around those app windows instead of covering the whole display.

The fragment shader (`PatternShaders.metal`) generates the mask patterns
procedurally from screen-space pixel coordinates. No textures are bound, and
each frame is a single full-screen triangle — a 5K display is sub-millisecond
on any M-series Mac.

Brightness support has two layers:

- Full-display mode can nudge hardware brightness and apply a mild gamma assist
  while Privacy Mode is active. The default brightness target is 20%.
- App-window mode uses local shader dimming inside the targeted overlay
  rectangles, because macOS brightness and gamma APIs are display-wide.

## Feasibility: software mask vs. hardware privacy

**True per-pixel shutdown is not possible from a user-space macOS app.**
Hardware privacy modes (Samsung, ASUS PrivacyVision, etc.) use a switchable
liquid-crystal privacy layer *inside the panel* that physically narrows the
cone of light. The OS does not expose it, and macOS has no equivalent API even
on Apple silicon. What this app does is:

- Composite a high-contrast mask pattern on top of the desktop. To an observer
  at a shallow angle the mask optically dominates; to the direct viewer it's
  easy to see "through" because the brain integrates the gaps.
- Offer adjustable density and strength so you can tune the privacy/readability
  trade-off for your panel.
- Optionally limit Privacy Mode to chosen app windows, so sensitive apps can be
  veiled without covering the entire desktop.

This is genuinely useful in public spaces but is an *approximation*. The About
section of the app states this plainly so users don't confuse the two.

### Where permissions matter

The overlay itself needs **no permissions** — a screen-saver-level transparent
window is a standard capability. The two statuses we surface are for optional
enhancements:

| Permission        | Needed for                                               |
|-------------------|----------------------------------------------------------|
| Accessibility     | Reliable frontmost-app detection when Messages/Mail hold secure input focus — powers more robust app rules. |
| Screen Recording  | Future "Adaptive Text" enhancement that reads on-screen text regions and shifts the pattern to break their edges. |

Neither is required for v1 features.

### Sandboxing

The entitlements file disables App Sandbox. Reasons:

- `CGWindowLevelForKey(.screenSaverWindow)` + cross-Space collection behavior
  works under sandbox but is unreliable at window-level boundaries on some
  macOS versions.
- `NSWorkspace.didActivateApplicationNotification` payloads are richer
  unsandboxed.
- Carbon `RegisterEventHotKey` works either way, but ships more predictably
  without sandbox.

If you need to sandbox the app for distribution (Mac App Store), keep the
overlay code as-is and add `com.apple.security.automation.apple-events` +
`com.apple.security.temporary-exception.mach-register` as needed.

## Known limitations

- The overlay cannot sit above Control Center, screenshot UI, or the menu bar
  dropdown — these are owned by `WindowServer` and use a higher level we can't
  match.
- On Apple silicon Macs, a notched built-in display will have the notch area
  remain transparent (we don't drop into the notch region).
- Live Preview uses a CPU renderer so it can live inside the SwiftUI view
  tree. The real overlay always uses the GPU path.
