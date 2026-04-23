//
//  DisplayManager.swift
//  Pixel Veil
//
//  Tracks attached NSScreens and emits changes. Uses the CGDisplay reconfiguration
//  callback for hot-plug events and also listens to NSApplication.didChangeScreenParameters
//  which covers wake-from-sleep and resolution changes.
//

import AppKit
import Combine

final class DisplayManager: ObservableObject {
    @Published private(set) var screens: [NSScreen] = NSScreen.screens

    private var reconfigRegistered = false
    private var noteObserver: NSObjectProtocol?

    func start() {
        refresh()

        noteObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in self?.refresh() }

        if !reconfigRegistered {
            let me = Unmanaged.passUnretained(self).toOpaque()
            CGDisplayRegisterReconfigurationCallback({ _, _, userInfo in
                guard let userInfo = userInfo else { return }
                let me = Unmanaged<DisplayManager>.fromOpaque(userInfo).takeUnretainedValue()
                DispatchQueue.main.async { me.refresh() }
            }, me)
            reconfigRegistered = true
        }
    }

    deinit {
        if let obs = noteObserver { NotificationCenter.default.removeObserver(obs) }
    }

    func refresh() {
        let fresh = NSScreen.screens
        if fresh.map({ Self.displayID(for: $0) ?? 0 }) !=
            screens.map({ Self.displayID(for: $0) ?? 0 }) ||
           fresh.count != screens.count {
            screens = fresh
        } else {
            // Frames may have changed even if identity set didn't.
            screens = fresh
        }
    }

    /// Returns the CGDirectDisplayID for an NSScreen, using the private-but-stable
    /// `NSScreenNumber` key that Apple has documented in release notes.
    static func displayID(for screen: NSScreen) -> UInt32? {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        return (screen.deviceDescription[key] as? NSNumber)?.uint32Value
    }

    /// Best-effort human name (product name if IOKit exposes it, else a built-in
    /// fallback).
    static func name(for screen: NSScreen) -> String {
        if #available(macOS 14.0, *) {
            return screen.localizedName
        }
        return Self.displayID(for: screen).map { "Display \($0)" } ?? "Display"
    }
}
