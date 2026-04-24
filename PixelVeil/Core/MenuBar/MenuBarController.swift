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
    // Variable length so the status item matches the mark's natural aspect
    // (wider than tall) without squashing.
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let popover = NSPopover()
    private let settings: SettingsStore
    private let overlayController: OverlayController
    private let permissionsManager: PermissionsManager
    private let hotkeyManager: HotkeyManager
    private let showMainWindow: () -> Void

    init(settings: SettingsStore,
         overlayController: OverlayController,
         permissionsManager: PermissionsManager,
         hotkeyManager: HotkeyManager,
         showMainWindow: @escaping () -> Void) {
        self.settings = settings
        self.overlayController = overlayController
        self.permissionsManager = permissionsManager
        self.hotkeyManager = hotkeyManager
        self.showMainWindow = showMainWindow
        super.init()
    }

    func install() {
        if let button = statusItem.button {
            button.image = AppImages.menuBarIcon(height: 18, withBadge: false)
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
        button.image = AppImages.menuBarIcon(height: 18, withBadge: active)
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

    // MARK: Glyph

    /// The menu-bar icon — a 3×3 grid template. Active = filled squares + a
    /// small badge dot in the upper-right; Inactive = hollow outlines only.
    /// Both states are template images so AppKit tints them to match the
    /// menu bar in light/dark appearance.
    private static func glyph(active: Bool) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let img = NSImage(size: size, flipped: false) { rect in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            let cell: CGFloat = 3
            let gap: CGFloat = 1
            let totalSide = cell * 3 + gap * 2
            let startX = (rect.width  - totalSide) / 2
            let startY = (rect.height - totalSide) / 2

            ctx.setFillColor(NSColor.labelColor.cgColor)
            ctx.setStrokeColor(NSColor.labelColor.cgColor)

            if active {
                for r in 0..<3 {
                    for c in 0..<3 {
                        let x = startX + CGFloat(c) * (cell + gap)
                        let y = startY + CGFloat(r) * (cell + gap)
                        ctx.fill(CGRect(x: x, y: y, width: cell, height: cell))
                    }
                }
                let dotR: CGFloat = 2.3
                let dotX = rect.width  - dotR * 2 - 0.5
                let dotY = rect.height - dotR * 2 - 0.5
                ctx.fillEllipse(in: CGRect(x: dotX, y: dotY,
                                           width: dotR * 2, height: dotR * 2))
            } else {
                ctx.setLineWidth(1)
                for r in 0..<3 {
                    for c in 0..<3 {
                        let x = startX + CGFloat(c) * (cell + gap) + 0.5
                        let y = startY + CGFloat(r) * (cell + gap) + 0.5
                        ctx.stroke(CGRect(x: x, y: y,
                                          width: cell - 1, height: cell - 1))
                    }
                }
            }
            return true
        }
        img.isTemplate = true
        return img
    }

    private func openMainWindow() {
        popover.performClose(nil)
        showMainWindow()
    }

    // MARK: Glyph

}
