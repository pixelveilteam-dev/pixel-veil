//
//  HotkeyManager.swift
//  Pixel Veil
//
//  Thin wrapper around Carbon's RegisterEventHotKey. Carbon is the only stable
//  way to get a true *global* hotkey on macOS from a sandbox-compatible app
//  without requiring Accessibility permission. We translate NSEvent modifier
//  flags to/from Carbon's modifier bits in the recorder view; this class deals
//  only in Carbon values.
//

import AppKit
import Carbon.HIToolbox
import Foundation

final class HotkeyManager: ObservableObject {
    var onTrigger: (() -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private let signature: OSType = OSType(0x50565648) // 'PVVH'
    private var currentID: UInt32 = 1

    init() {
        installHandler()
    }

    deinit {
        unregister()
        if let h = handlerRef { RemoveEventHandler(h) }
    }

    func register(_ spec: HotkeySpec) {
        unregister()
        // A keyCode of 0 with no modifiers means "unbound".
        guard spec.keyCode != 0 || spec.modifiers != 0 else { return }

        var ref: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: signature, id: currentID)
        currentID &+= 1

        let status = RegisterEventHotKey(
            spec.keyCode,
            spec.modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &ref
        )
        if status == noErr { self.hotKeyRef = ref }
    }

    func unregister() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
    }

    private func installHandler() {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                 eventKind: UInt32(kEventHotKeyPressed))
        let userData = Unmanaged.passUnretained(self).toOpaque()

        InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, event, userData) -> OSStatus in
                guard let userData = userData, let event = event else { return noErr }
                var hkID = EventHotKeyID()
                let status = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hkID
                )
                guard status == noErr else { return status }
                let me = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
                DispatchQueue.main.async { me.onTrigger?() }
                return noErr
            },
            1,
            &spec,
            userData,
            &handlerRef
        )
    }
}

// MARK: - Translation helpers for the recorder UI.

enum HotkeyTranslation {
    /// NSEvent.ModifierFlags -> Carbon modifier mask.
    static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var m: UInt32 = 0
        if flags.contains(.command) { m |= UInt32(cmdKey) }
        if flags.contains(.option)  { m |= UInt32(optionKey) }
        if flags.contains(.control) { m |= UInt32(controlKey) }
        if flags.contains(.shift)   { m |= UInt32(shiftKey) }
        return m
    }

    static func nsFlags(from carbon: UInt32) -> NSEvent.ModifierFlags {
        var f = NSEvent.ModifierFlags()
        if carbon & UInt32(cmdKey) != 0    { f.insert(.command) }
        if carbon & UInt32(optionKey) != 0 { f.insert(.option) }
        if carbon & UInt32(controlKey) != 0 { f.insert(.control) }
        if carbon & UInt32(shiftKey) != 0  { f.insert(.shift) }
        return f
    }

    /// Produce a short user-visible string like "⌃⌥P".
    static func displayString(_ spec: HotkeySpec) -> String {
        var s = ""
        if spec.modifiers & UInt32(controlKey) != 0 { s += "⌃" }
        if spec.modifiers & UInt32(optionKey) != 0  { s += "⌥" }
        if spec.modifiers & UInt32(shiftKey) != 0   { s += "⇧" }
        if spec.modifiers & UInt32(cmdKey) != 0     { s += "⌘" }
        s += keyString(forKeyCode: spec.keyCode)
        return s.isEmpty ? "—" : s
    }

    private static func keyString(forKeyCode keyCode: UInt32) -> String {
        // A small mapping is sufficient for the common letter/number keys that
        // make reasonable global hotkeys. Non-printable keys return a symbol.
        let map: [UInt32: String] = [
            0: "A", 11: "B", 8: "C", 2: "D", 14: "E", 3: "F", 5: "G", 4: "H",
            34: "I", 38: "J", 40: "K", 37: "L", 46: "M", 45: "N", 31: "O",
            35: "P", 12: "Q", 15: "R", 1: "S", 17: "T", 32: "U", 9: "V",
            13: "W", 7: "X", 16: "Y", 6: "Z",
            18: "1", 19: "2", 20: "3", 21: "4", 23: "5", 22: "6",
            26: "7", 28: "8", 25: "9", 29: "0",
            49: "Space", 36: "↩", 53: "⎋", 51: "⌫",
            123: "←", 124: "→", 125: "↓", 126: "↑"
        ]
        return map[keyCode] ?? "?"
    }
}
