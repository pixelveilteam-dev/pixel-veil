//
//  PixelVeilApp.swift
//  Pixel Veil
//
//  The SwiftUI app entry point. Most lifecycle work is delegated to AppDelegate so
//  we can own an NSStatusItem, global hotkey, and the overlay windows directly.
//

import SwiftUI

@main
struct PixelVeilApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // The main settings-style window. Using `Window` (not `WindowGroup`) so
        // only one instance ever exists and macOS treats it like a utility app.
        Window("Pixel Veil", id: "pixel-veil-main") {
            RootView()
                .environmentObject(appDelegate.settings)
                .environmentObject(appDelegate.overlayController)
                .environmentObject(appDelegate.displayManager)
                .environmentObject(appDelegate.permissionsManager)
                .environmentObject(appDelegate.hotkeyManager)
                .environmentObject(appDelegate.appRuleEngine)
                .environmentObject(appDelegate.scheduleEngine)
                .environmentObject(appDelegate.updateChecker)
                .frame(minWidth: 980, minHeight: 680)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(after: .appInfo) {
                Button("Check Permissions…") {
                    appDelegate.permissionsManager.refresh()
                }
            }
        }
    }
}
