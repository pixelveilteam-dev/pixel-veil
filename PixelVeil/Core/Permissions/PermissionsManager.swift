//
//  PermissionsManager.swift
//  Pixel Veil
//
//  Tracks the two permissions the app *might* need depending on how the user
//  configures it.
//
//  Accessibility — required only if we wanted to observe keystrokes for an app
//  that uses secure input, or to drive features like "pause when typing in
//  Messages". The base overlay does not need it; we expose the status anyway
//  so users can grant it if they turn on app-rule-driven automation.
//
//  Screen Recording — not required for the overlay itself (we don't read
//  screen contents), but is needed if the user enables Adaptive Text mode's
//  optional "shift pattern with text regions" enhancement. Surfacing the
//  status here keeps everything discoverable.
//

import AppKit
import Combine
import CoreGraphics

enum PermissionState: String {
    case granted
    case denied
    case unknown
}

final class PermissionsManager: ObservableObject {
    @Published var accessibility: PermissionState = .unknown
    @Published var screenRecording: PermissionState = .unknown

    func refresh() {
        accessibility   = Self.checkAccessibility()
        screenRecording = Self.checkScreenRecording()
    }

    func requestAccessibility() {
        // Surfaces the system prompt on first call, otherwise opens Settings.
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let opts: CFDictionary = [key: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(opts)

        // If already prompted once, jump users to the pane.
        if accessibility != .granted {
            let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
            NSWorkspace.shared.open(url)
        }
        refresh()
    }

    func requestScreenRecording() {
        // CGPreflightScreenCaptureAccess triggers the system prompt on first use.
        let granted = CGPreflightScreenCaptureAccess()
        if !granted { _ = CGRequestScreenCaptureAccess() }

        if screenRecording != .granted {
            let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!
            NSWorkspace.shared.open(url)
        }
        refresh()
    }

    // MARK: Checks

    private static func checkAccessibility() -> PermissionState {
        AXIsProcessTrusted() ? .granted : .denied
    }

    private static func checkScreenRecording() -> PermissionState {
        CGPreflightScreenCaptureAccess() ? .granted : .denied
    }
}
