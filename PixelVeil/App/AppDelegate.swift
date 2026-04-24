//
//  AppDelegate.swift
//  Pixel Veil
//
//  Wires together the long-lived services. SwiftUI owns views; AppDelegate owns
//  NSStatusItem, overlay windows, Carbon hotkey registration, and workspace
//  observers — all things that want an NSApplication lifecycle, not a view tree.
//

import AppKit
import Combine
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    // MARK: Services
    let settings           = SettingsStore()
    let displayManager     = DisplayManager()
    let permissionsManager = PermissionsManager()
    let hotkeyManager      = HotkeyManager()
    let appRuleEngine      = AppRuleEngine()
    let scheduleEngine     = ScheduleEngine()
    let brightnessController = BrightnessController()
    let gammaAssistController = GammaAssistController()
    let launchAtLoginController = LaunchAtLoginController()
    let updateChecker        = UpdateChecker()
    lazy var overlayController = OverlayController(settings: settings,
                                                   displayManager: displayManager)
    private var menuBarController: MenuBarController?
    private let mainWindowIdentifier = NSUserInterfaceItemIdentifier("pixel-veil-main")
    private var windowObserverTokens: [NSObjectProtocol] = []

    private var bag = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Identify as a regular app so the main window behaves normally, but we
        // still run a status item in parallel.
        NSApp.setActivationPolicy(.regular)

        // Use the full Pixel Veil logo as the Dock / Cmd-Tab icon. We set it
        // at runtime because we don't ship an ICNS (no Xcode asset catalog
        // in this build pipeline) — setting `applicationIconImage` updates
        // the Dock tile live and sticks for the lifetime of the process.
        let icon = AppImages.withText
        if icon.size.width > 0 {
            NSApplication.shared.applicationIconImage = icon
        }

        // Ensure ~/Library/Application Support/PixelVeil exists so users have
        // a clear drop target for their Live Preview wallpaper.
        if let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            let dir = base.appendingPathComponent("PixelVeil", isDirectory: true)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }

        displayManager.start()
        permissionsManager.refresh()
        updateChecker.start()

        // Bind services to the shared settings store.
        overlayController.appRuleEngine = appRuleEngine
        overlayController.bind()
        appRuleEngine.bind(settings: settings, overlay: overlayController)
        scheduleEngine.bind(settings: settings, overlay: overlayController)
        installMainWindowLifecycle()

        // When the active app rule changes, its strength / pattern overrides
        // must be reflected in the live overlay. We piggy-back on the
        // existing sync() path by re-emitting settings.displays (a cheap no-op
        // value write) — OverlayController's sync fires on any of these.
        appRuleEngine.$activeRule
            .dropFirst()
            .sink { [weak self] _ in
                // Async hop: same willSet commit-timing reason — we need
                // `activeRule` to be readable back from the AppRuleEngine
                // when the overlay's sync() runs.
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    let snapshot = self.settings.displays
                    self.settings.displays = snapshot
                }
            }
            .store(in: &bag)

        // Global hotkey: toggle Privacy Mode.
        hotkeyManager.onTrigger = { [weak self] in
            self?.settings.isEnabled.toggle()
        }
        settings.$hotkey
            .sink { [weak self] spec in self?.hotkeyManager.register(spec) }
            .store(in: &bag)

        // Menu bar item + popover.
        menuBarController = MenuBarController(
            settings: settings,
            overlayController: overlayController,
            permissionsManager: permissionsManager,
            hotkeyManager: hotkeyManager,
            showMainWindow: { [weak self] in self?.showMainWindow() }
        )
        menuBarController?.install()

        // The menu bar glyph follows the user's explicit toggle — the same
        // source every in-app indicator uses. This keeps the glyph, the
        // popover pill, the Overview pill, and the toggle itself in lock-step.
        // Rule/schedule overrides surface as separate pills, not by flipping
        // this icon.
        settings.$isEnabled
            .receive(on: DispatchQueue.main)
            .sink { [weak self] active in self?.menuBarController?.setActive(active) }
            .store(in: &bag)

        launchAtLoginController.sync(enabled: settings.launchAtLogin)
        settings.$launchAtLogin
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] enabled in
                self?.launchAtLoginController.sync(enabled: enabled)
            }
            .store(in: &bag)

        // Drive the brightness controller from the resolved active state and
        // the user's dim preferences. On every transition:
        //   * active + dimBrightness  → snapshot+ramp down to dimTarget
        //   * inactive OR !dimBrightness → ramp back to saved values
        //
        // If the user changes dimTarget while already dimmed, re-apply so the
        // new target takes effect without touching the saved "original"
        // brightness.
        Publishers.CombineLatest4(
            overlayController.$isActive,
            settings.$dimBrightness,
            settings.$dimTarget,
            appRuleEngine.$activeRule
        )
        .sink { [weak self] active, enabled, target, activeRule in
            guard let self = self else { return }
            if active && enabled && activeRule?.limitToAppWindows != true {
                self.brightnessController.applyDim(target: Float(max(0.0, min(1.0, target))))
            } else {
                self.brightnessController.restore()
            }
        }
        .store(in: &bag)

        Publishers.CombineLatest4(
            overlayController.$isActive,
            settings.$dimBrightness,
            settings.$strength,
            settings.$displays
        )
        .combineLatest(appRuleEngine.$activeRule)
        .sink { [weak self] values, activeRule in
            guard let self = self else { return }
            let (active, assistEnabled, strength, displaySettings) = values
            if active && assistEnabled && activeRule?.limitToAppWindows != true {
                let configured = Dictionary(uniqueKeysWithValues: displaySettings.map { ($0.id, $0.enabled) })
                let enabledIDs = Set(self.displayManager.screens.compactMap { screen -> CGDirectDisplayID? in
                    guard let id = DisplayManager.displayID(for: screen) else { return nil }
                    return configured[id, default: true] ? id : nil
                })
                let gammaFactor = 1.0 - max(0.0, min(1.0, strength)) * 0.35
                self.gammaAssistController.applyAssist(
                    factor: gammaFactor,
                    enabledDisplayIDs: enabledIDs.isEmpty ? nil : enabledIDs
                )
            } else {
                self.gammaAssistController.restore()
            }
        }
        .store(in: &bag)
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Restore brightness synchronously — if we return from terminate while
        // the panel is still dimmed, the user is left in the dark.
        gammaAssistController.restore()
        brightnessController.restoreImmediately()
        overlayController.tearDown()
        hotkeyManager.unregister()
        windowObserverTokens.forEach(NotificationCenter.default.removeObserver)
        windowObserverTokens.removeAll()
    }

    // Keep the app alive when the main window is closed — Pixel Veil is a utility
    // that lives in the menu bar.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication,
                                       hasVisibleWindows flag: Bool) -> Bool {
        showMainWindow()
        return true
    }
}

extension AppDelegate: NSWindowDelegate {
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard isMainSettingsWindow(sender) else { return true }
        sender.orderOut(nil)
        NSApp.setActivationPolicy(.accessory)
        return false
    }

    private func installMainWindowLifecycle() {
        let center = NotificationCenter.default
        for name in [NSWindow.didBecomeMainNotification, NSWindow.didBecomeKeyNotification] {
            let token = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.configureMainSettingsWindow()
            }
            windowObserverTokens.append(token)
        }

        DispatchQueue.main.async { [weak self] in
            self?.configureMainSettingsWindow()
        }
    }

    private func showMainWindow() {
        NSApp.setActivationPolicy(.regular)
        configureMainSettingsWindow()

        if let window = NSApp.windows.first(where: isMainSettingsWindow) {
            window.makeKeyAndOrderFront(nil)
        }

        NSApp.activate(ignoringOtherApps: true)
    }

    private func configureMainSettingsWindow() {
        for window in NSApp.windows where isMainSettingsWindow(window) {
            window.identifier = mainWindowIdentifier
            window.isReleasedWhenClosed = false
            window.delegate = self
        }
    }

    private func isMainSettingsWindow(_ window: NSWindow) -> Bool {
        window.identifier == mainWindowIdentifier || window.title == "Pixel Veil"
    }
}
