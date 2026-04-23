//
//  PreferencesModel.swift
//  Pixel Veil
//
//  Plain data types that describe user preferences. Kept Codable so the whole
//  tree round-trips through UserDefaults as a single JSON blob.
//

import Foundation

enum PatternMode: String, Codable, CaseIterable, Identifiable {
    case verticalStripes
    case horizontalLines
    case checkerboard
    case adaptiveText
    case custom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .verticalStripes: return "Vertical Stripes"
        case .horizontalLines: return "Horizontal Lines"
        case .checkerboard:    return "Checkerboard"
        case .adaptiveText:    return "Adaptive Text"
        case .custom:          return "Custom Pattern"
        }
    }

    var symbol: String {
        switch self {
        case .verticalStripes: return "rectangle.split.3x1"
        case .horizontalLines: return "rectangle.split.1x2"
        case .checkerboard:    return "square.grid.2x2"
        case .adaptiveText:    return "textformat"
        case .custom:          return "slider.horizontal.3"
        }
    }
}

// Serialized hotkey specification. We store Carbon key/modifier codes because
// that's what RegisterEventHotKey takes; the recorder view converts to/from
// NSEvent modifierFlags and key equivalents.
struct HotkeySpec: Codable, Equatable {
    var keyCode: UInt32      // Carbon virtual key code
    var modifiers: UInt32    // Carbon modifier mask (cmdKey | optionKey | ...)

    static let defaultHotkey = HotkeySpec(keyCode: 35 /* 'P' */,
                                          modifiers: 0x0900 /* control + option */)
}

// A single per-display configuration. `displayID` is the CGDirectDisplayID;
// if the display disconnects we keep the entry so settings survive replugs.
struct DisplaySettings: Codable, Identifiable, Equatable {
    var id: UInt32               // CGDirectDisplayID
    var name: String
    var enabled: Bool = true
    var strengthOverride: Double? = nil   // nil = use global
    var patternOverride: PatternMode? = nil
}

enum AppRuleAction: String, Codable, CaseIterable {
    case activate    // turn Privacy Mode ON when this app is frontmost
    case deactivate  // turn Privacy Mode OFF when this app is frontmost
}

struct AppRule: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var bundleIdentifier: String
    var displayName: String
    var action: AppRuleAction
    // Optional per-rule overrides. Applied while this rule is the match for
    // the frontmost app AND its action is .activate.
    var strengthOverride: Double? = nil
    var patternOverride: PatternMode? = nil
}

struct ScheduleRule: Codable, Equatable {
    var isEnabled: Bool = false
    // Bitmask of weekdays (1 = Sunday ... 7 = Saturday) using Calendar.Component.weekday values.
    var weekdays: Set<Int> = [2, 3, 4, 5, 6] // Mon-Fri by default
    var startHour: Int = 9
    var startMinute: Int = 0
    var endHour: Int = 17
    var endMinute: Int = 0
}

struct Preferences: Codable, Equatable {
    var isEnabled: Bool = false
    // Default lowered — with the contrast-reduction shader, 0.55 is the sweet
    // spot where the direct viewer keeps ~5:1 contrast (comfortable reading)
    // while side viewers already fall below ~2:1.
    var strength: Double = 0.55          // 0.0 ... 1.0
    var density: Double = 0.6            // 0.0 ... 1.0 — controls stripe/check spacing
    var pattern: PatternMode = .adaptiveText
    var customPatternBase64: String? = nil   // reserved for custom pattern image data

    var hotkey: HotkeySpec = .defaultHotkey

    var displays: [DisplaySettings] = []
    var appRules: [AppRule] = []
    var schedule: ScheduleRule = ScheduleRule()

    // If true, Privacy Mode only runs when one of the "activate" rules is
    // frontmost. If false, rules can temporarily override the master state.
    var appRulesRestrictive: Bool = false

    // When true, Privacy Mode also forces the display brightness down to
    // `dimTarget` (fraction of 0...1). The original brightness is restored
    // when Privacy Mode deactivates or the app quits.
    var dimBrightness: Bool = true
    var dimTarget: Double = 0.20
}
