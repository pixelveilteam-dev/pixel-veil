//
//  OverlayController.swift
//  Pixel Veil
//
//  Owns one OverlayWindow per active display. Listens to SettingsStore and
//  DisplayManager, and exposes an "effective state" that the AppRuleEngine /
//  ScheduleEngine can override without mutating the user's master toggle.
//
//  The controller separates three layers of intent:
//
//    1. User intent         — `settings.isEnabled` (the big toggle)
//    2. Automation overrides — app rules, schedule (isForcedOn / isForcedOff)
//    3. Effective state     — what actually gets rendered on screen
//
//  Automation pieces only flip the overrides; the master toggle is never
//  written behind the user's back.
//

import AppKit
import Combine

final class OverlayController: ObservableObject {
    private let settings: SettingsStore
    private let displayManager: DisplayManager
    /// Set by AppDelegate after AppRuleEngine is wired up. When non-nil and its
    /// strength/pattern overrides are set, they take precedence over the
    /// global settings in `sync()`.
    var appRuleEngine: AppRuleEngine?

    /// External override: rules / schedule can force ON or OFF.
    @Published var forcedOn: Bool = false
    @Published var forcedOff: Bool = false

    /// True iff any overlay window is currently rendering.
    @Published private(set) var isRenderingAny: Bool = false

    /// Published mirror of the resolved "should the overlay be on" state.
    /// This is the single source of truth the UI should bind to for the
    /// Active / Inactive indicator — a plain computed property wouldn't
    /// republish when settings.isEnabled changes without the view also
    /// observing settings.
    @Published private(set) var isActive: Bool = false

    // displayID -> (window, metal view)
    private var windows: [UInt32: (OverlayWindow, MetalPatternView)] = [:]
    private var bag = Set<AnyCancellable>()
    private var spaceObserver: NSObjectProtocol?
    private var isSyncing = false

    init(settings: SettingsStore, displayManager: DisplayManager) {
        self.settings = settings
        self.displayManager = displayManager
    }

    func bind() {
        // Any relevant change re-evaluates which overlays should be visible.
        //
        // IMPORTANT: the sink body is deferred with DispatchQueue.main.async.
        // @Published emits its new value in `willSet`, *before* the backing
        // storage is actually updated. If sync() ran synchronously in the
        // sink and read settings.isEnabled directly, it would observe the
        // OLD value — making the overlay creation lag one click behind the
        // toggle (brightness changes on the right click, pattern on the next
        // one). Hopping to the next main-queue tick gets us past willSet.
        Publishers.CombineLatest4(
            settings.$isEnabled,
            settings.$strength.combineLatest(settings.$density),
            settings.$pattern,
            settings.$displays
        )
        .combineLatest(Publishers.CombineLatest($forcedOn, $forcedOff))
        .combineLatest(displayManager.$screens)
        .sink { [weak self] _, _ in
            DispatchQueue.main.async { self?.sync() }
        }
        .store(in: &bag)

        // `isActive` is driven directly from the inputs so UI observers see it
        // update the same tick the toggle flips — without waiting for sync()
        // to finish. This eliminates the race where the pill briefly reads
        // "Inactive" while the toggle is already on.
        Publishers.CombineLatest3(
            settings.$isEnabled,
            $forcedOn,
            $forcedOff
        )
        .map { enabled, on, off -> Bool in
            if off { return false }
            if on  { return true }
            return enabled
        }
        .removeDuplicates()
        .receive(on: DispatchQueue.main)
        .assign(to: &$isActive)

        // Spaces don't always re-attach `.canJoinAllSpaces` windows cleanly
        // when you swipe between desktops. `activeSpaceDidChange` fires mid-
        // transition, so we sync immediately AND again after the animation
        // settles — belt and braces for the common "overlay vanishes on
        // desktop swipe" glitch.
        spaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.sync()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                self?.reassertAllVisible()
            }
        }

        sync()
    }

    deinit {
        if let obs = spaceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(obs)
        }
    }

    /// Force every existing overlay window to re-assert itself at the screen-
    /// saver level and front-order. Used after a Space swipe in case the
    /// window server dropped one. Cheap — a no-op for windows already where
    /// they should be.
    private func reassertAllVisible() {
        guard effectiveEnabled else { return }
        for (_, pair) in windows {
            pair.0.orderFrontRegardless()
            pair.1.needsDisplay = true
        }
    }

    func tearDown() {
        for (_, pair) in windows {
            // Nuke the content view BEFORE ordering out so any in-flight
            // Metal drawable is released. Without this, a window that
            // re-appears across a Space switch can briefly present its last
            // rendered pattern frame.
            pair.0.contentView = nil
            pair.0.orderOut(nil)
        }
        windows.removeAll()
        isRenderingAny = false
    }

    // MARK: Effective-state resolution

    var effectiveEnabled: Bool {
        if forcedOff { return false }
        if forcedOn { return true }
        return settings.isEnabled
    }

    // MARK: Sync

    private func sync() {
        // Guard against reentrance — sync() can be triggered by multiple
        // publishers firing in the same tick (isEnabled + displays + spaces
        // all changing together). A second entry mid-teardown would mutate
        // `windows` while we're iterating it.
        if isSyncing { return }
        isSyncing = true
        defer { isSyncing = false }

        let screens = displayManager.screens
        let globallyOn = effectiveEnabled

        // Add/update one overlay per active screen.
        for screen in screens {
            let displayID = DisplayManager.displayID(for: screen) ?? 0
            let perDisplay = settings.settings(for: displayID)
            let enabledForDisplay = perDisplay?.enabled ?? true
            let shouldShow = globallyOn && enabledForDisplay

            // Precedence: per-display override > active app-rule override >
            // global setting. This keeps per-display customisation supreme for
            // users who specifically tuned a monitor, while allowing app rules
            // to quietly adjust both strength and pattern for anything not
            // explicitly overridden.
            let appStrength = appRuleEngine?.activeRule?.strengthOverride
            let appPattern  = appRuleEngine?.activeRule?.patternOverride
            let strength = perDisplay?.strengthOverride ?? appStrength ?? settings.strength
            let pattern  = perDisplay?.patternOverride  ?? appPattern  ?? settings.pattern

            if shouldShow {
                let pair = windows[displayID] ?? makeWindow(for: screen, id: displayID)
                pair.1.update(strength: strength,
                              density: settings.density,
                              pattern: pattern)
                pair.0.setFrame(screen.frame, display: true)
                if !pair.0.isVisible {
                    pair.0.orderFrontRegardless()
                }
                windows[displayID] = pair
            } else if let pair = windows[displayID] {
                // Hard tear-down: drop the MetalPatternView so no stale frame
                // can be presented if the window comes back via a Space swap.
                pair.0.contentView = nil
                pair.0.orderOut(nil)
                windows.removeValue(forKey: displayID)
            }
        }

        // Drop windows whose screens disappeared.
        let live = Set(screens.compactMap { DisplayManager.displayID(for: $0) })
        for id in windows.keys where !live.contains(id) {
            windows[id]?.0.contentView = nil
            windows[id]?.0.orderOut(nil)
            windows.removeValue(forKey: id)
        }

        isRenderingAny = !windows.isEmpty
    }

    private func makeWindow(for screen: NSScreen, id: UInt32) -> (OverlayWindow, MetalPatternView) {
        let window = OverlayWindow(screen: screen)
        // Metal is present on every Mac that runs macOS 13+. If initialization
        // fails it indicates a corrupted install; crashing with a clear message
        // beats silently rendering nothing.
        guard let metal = MetalPatternView.make() else {
            preconditionFailure("Metal is required but unavailable on this system")
        }
        metal.frame = window.contentView?.bounds ?? .zero
        metal.autoresizingMask = [.width, .height]
        window.contentView = metal
        return (window, metal)
    }
}
