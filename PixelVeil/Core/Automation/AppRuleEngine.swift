//
//  AppRuleEngine.swift
//  Pixel Veil
//
//  Observes the frontmost application and asks the OverlayController to force
//  Privacy Mode on or off according to the user's rules.
//
//  Rule evaluation
//  ---------------
//  * If the frontmost app matches an `activate` rule → force ON.
//  * If the frontmost app matches a `deactivate` rule → force OFF.
//  * Otherwise, behaviour depends on `appRulesRestrictive`:
//      - restrictive = false: clear overrides, fall back to master toggle.
//      - restrictive = true: force OFF unless an activate rule is matched.
//

import AppKit
import Combine

final class AppRuleEngine: ObservableObject {
    /// The rule currently matching the frontmost app, if any. OverlayController
    /// observes this and applies per-rule strength / pattern overrides.
    @Published private(set) var activeRule: AppRule?

    private weak var settings: SettingsStore?
    private weak var overlay: OverlayController?

    private var workspaceObserver: NSObjectProtocol?
    private var bag = Set<AnyCancellable>()

    func bind(settings: SettingsStore, overlay: OverlayController) {
        self.settings = settings
        self.overlay  = overlay

        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            self?.evaluate(frontmost: app)
        }

        // Re-evaluate when rules change. Async hop for the same willSet reason
        // documented in OverlayController.bind — we must let the store's
        // @Published writes commit before we read them back in evaluate().
        settings.$appRules
            .combineLatest(settings.$appRulesRestrictive)
            .sink { [weak self] _, _ in
                DispatchQueue.main.async {
                    self?.evaluate(frontmost: NSWorkspace.shared.frontmostApplication)
                }
            }
            .store(in: &bag)

        DispatchQueue.main.async { [weak self] in
            self?.evaluate(frontmost: NSWorkspace.shared.frontmostApplication)
        }
    }

    deinit {
        if let obs = workspaceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(obs)
        }
    }

    private func evaluate(frontmost: NSRunningApplication?) {
        guard let settings = settings, let overlay = overlay else { return }
        let bundleID = frontmost?.bundleIdentifier

        let match = settings.appRules.first { rule in
            rule.bundleIdentifier == bundleID
        }

        // Only surface the active rule when it's actually steering behaviour,
        // i.e. it's an activate rule (deactivate rules turn privacy off and
        // have no overrides to apply).
        if let match = match, match.action == .activate {
            if activeRule != match { activeRule = match }
        } else if activeRule != nil {
            activeRule = nil
        }

        switch (match?.action, settings.appRulesRestrictive) {
        case (.activate, _):
            overlay.forcedOn = true
            overlay.forcedOff = false
        case (.deactivate, _):
            overlay.forcedOn = false
            overlay.forcedOff = true
        case (nil, true):
            overlay.forcedOn = false
            overlay.forcedOff = true
        case (nil, false):
            overlay.forcedOn = false
            overlay.forcedOff = false
        }
    }
}
