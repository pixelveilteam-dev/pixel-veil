# Changelog

All notable changes to Pixel Veil are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.1] — 2026-04-23

### Changed
- AppIcon now composites the Pixel Veil mark onto a rounded-square purple
  gradient canvas (Apple superellipse at 0.223 × side, 10 % safe-area
  inset, glassy top highlight, inner rim). The bare transparent mark
  looked out-of-place next to Apple's own icons in the Dock; this matches
  the macOS 11 + design language.
- `tools/make-app-icon.swift` generates the 1024 × 1024 source PNG from
  the standalone mark; ICNS is rebuilt from it.

## [1.0.0] — 2026-04-23

Initial public release.

### Added
- Metal-rendered privacy overlay (contrast-reduction veil) at screen-saver
  window level, one window per attached display, cross-Space aware.
- Five pattern modes: Vertical Stripes, Horizontal Lines, Checkerboard,
  Adaptive Text, Custom. All ride on top of the contrast veil.
- Forced display brightness dim via the private DisplayServices framework;
  auto-brightness is disabled while active and the original value is
  restored on deactivation or app quit.
- Hold-timer that re-applies the brightness target every 2 s to fight
  ambient-light adjustments.
- SwiftUI app window with sidebar navigation: Overview, Privacy Mode,
  Displays, Automation, Hotkeys, Permissions, About.
- NSStatusItem menu bar control with a 3×3 grid template glyph
  (filled + badge dot when active, hollow outlines when inactive) and a
  popover offering a quick toggle, strength slider, and navigation.
- Global hotkey via Carbon `RegisterEventHotKey` with a recorder UI.
- App rules driven by `NSWorkspace.didActivateApplicationNotification`
  with per-rule strength and pattern overrides.
- Minute-resolution schedule with per-weekday enable.
- Permissions surface for Accessibility and Screen Recording (both
  optional).
- Per-display overrides with hot-plug awareness.
- First-run onboarding sheet with illustrations.
- Preferences persisted to `UserDefaults` as a single JSON blob with a
  migration lane (`com.pixelveil.migrated.v1`).
- Distribution: signed `.app` bundle (ad-hoc with hardened runtime) and a
  styled DMG with drag-to-Applications UI, both produced via
  `build-app.sh` and `make-dmg.sh`.

### Notes on Gatekeeper
This release is ad-hoc signed because the project does not have an Apple
Developer ID ($99/yr). Users see a one-time "cannot verify developer"
dialog on first launch. `INSTALL.md` documents three bypass paths. Move
to Developer ID + notarization is planned when the developer account is
provisioned.
