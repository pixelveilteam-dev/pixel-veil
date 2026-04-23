//
//  MenuBarController.swift
//  Pixel Veil
//
//  Owns the NSStatusItem and its popover. We give the status item a custom
//  template image (a 3×3 grid glyph, evoking pixels) that picks up the
//  menu bar's dark/light mode automatically. When Privacy Mode is active we
//  swap in a tinted non-template image to match the reference screenshot.
//

import AppKit
import SwiftUI

final class MenuBarController: NSObject {
    // `variableLength` lets the status item match the natural aspect of our
    // icon — squareLength would force a 1:1 box and vertically squash the
    // wider-than-tall monitor+shield silhouette.
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let popover = NSPopover()
    private let settings: SettingsStore
    private let overlayController: OverlayController
    private let permissionsManager: PermissionsManager
    private let hotkeyManager: HotkeyManager

    init(settings: SettingsStore,
         overlayController: OverlayController,
         permissionsManager: PermissionsManager,
         hotkeyManager: HotkeyManager) {
        self.settings = settings
        self.overlayController = overlayController
        self.permissionsManager = permissionsManager
        self.hotkeyManager = hotkeyManager
        super.init()
    }

    func install() {
        if let button = statusItem.button {
            button.image = AppImages.menuBarSilhouette(height: 18, withBadge: false)
            button.imagePosition = .imageOnly
            button.target = self
            button.action = #selector(toggle(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.toolTip = "Pixel Veil"
        }

        popover.behavior = .transient
        popover.animates = true

        let content = MenuBarPopover(
            settings: settings,
            overlay: overlayController,
            openMainWindow: { [weak self] in self?.openMainWindow() },
            openSettings:   { [weak self] in self?.openMainWindow() },
            checkPermissions: { [weak self] in
                self?.permissionsManager.refresh()
            },
            quit: { NSApp.terminate(nil) }
        )
        popover.contentViewController = NSHostingController(rootView: content)
    }

    func setActive(_ active: Bool) {
        guard let button = statusItem.button else { return }
        // Both states are template NSImages (black silhouette + alpha) so
        // AppKit handles light/dark menu bar tinting for us. Active adds a
        // small filled badge dot so the state is unambiguous.
        button.image = AppImages.menuBarSilhouette(height: 18, withBadge: active)
    }

    @objc private func toggle(_ sender: Any?) {
        guard let button = statusItem.button else { return }
        // Right-click = direct toggle of Privacy Mode; left-click = popover.
        if let event = NSApp.currentEvent, event.type == .rightMouseUp {
            settings.isEnabled.toggle()
            return
        }
        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    private func openMainWindow() {
        popover.performClose(nil)
        NSApp.activate(ignoringOtherApps: true)
        // Find or recreate the main window.
        if let window = NSApp.windows.first(where: { $0.identifier?.rawValue == "pixel-veil-main" }) {
            window.makeKeyAndOrderFront(nil)
        } else {
            // SwiftUI will re-create on activation via the `Window` scene.
            NSApp.sendAction(#selector(NSApplication.runPageLayout(_:)), to: nil, from: nil)
        }
    }

    // MARK: Glyph

}
