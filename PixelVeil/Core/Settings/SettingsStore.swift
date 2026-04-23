//
//  SettingsStore.swift
//  Pixel Veil
//
//  An `ObservableObject` facade over `Preferences`. We publish individual fields
//  (rather than the whole struct) so SwiftUI views can bind to slivers without
//  re-rendering the world on every change. Writes are debounced and persisted
//  to UserDefaults as a single JSON blob.
//

import Combine
import Foundation

final class SettingsStore: ObservableObject {
    private static let defaultsKey = "com.pixelveil.preferences.v1"

    // Coarse-grained published fields used by UI.
    @Published var isEnabled: Bool
    @Published var strength: Double
    @Published var density: Double
    @Published var pattern: PatternMode
    @Published var hotkey: HotkeySpec
    @Published var displays: [DisplaySettings]
    @Published var appRules: [AppRule]
    @Published var schedule: ScheduleRule
    @Published var appRulesRestrictive: Bool
    @Published var dimBrightness: Bool
    @Published var dimTarget: Double

    private var bag = Set<AnyCancellable>()

    init() {
        let loaded = Self.load()
        self.isEnabled            = loaded.isEnabled
        self.strength             = loaded.strength
        self.density              = loaded.density
        self.pattern              = loaded.pattern
        self.hotkey               = loaded.hotkey
        self.displays             = loaded.displays
        self.appRules             = loaded.appRules
        self.schedule             = loaded.schedule
        self.appRulesRestrictive  = loaded.appRulesRestrictive
        self.dimBrightness        = loaded.dimBrightness
        self.dimTarget            = loaded.dimTarget

        // Persist whenever any of these changes (debounced).
        let saveTrigger = Publishers.MergeMany(
            $isEnabled.map { _ in () }.eraseToAnyPublisher(),
            $strength.map { _ in () }.eraseToAnyPublisher(),
            $density.map { _ in () }.eraseToAnyPublisher(),
            $pattern.map { _ in () }.eraseToAnyPublisher(),
            $hotkey.map { _ in () }.eraseToAnyPublisher(),
            $displays.map { _ in () }.eraseToAnyPublisher(),
            $appRules.map { _ in () }.eraseToAnyPublisher(),
            $schedule.map { _ in () }.eraseToAnyPublisher(),
            $appRulesRestrictive.map { _ in () }.eraseToAnyPublisher(),
            $dimBrightness.map { _ in () }.eraseToAnyPublisher(),
            $dimTarget.map { _ in () }.eraseToAnyPublisher()
        )
        saveTrigger
            .debounce(for: .milliseconds(200), scheduler: DispatchQueue.main)
            .sink { [weak self] in self?.save() }
            .store(in: &bag)
    }

    var snapshot: Preferences {
        Preferences(
            isEnabled: isEnabled,
            strength: strength,
            density: density,
            pattern: pattern,
            hotkey: hotkey,
            displays: displays,
            appRules: appRules,
            schedule: schedule,
            appRulesRestrictive: appRulesRestrictive,
            dimBrightness: dimBrightness,
            dimTarget: dimTarget
        )
    }

    // MARK: Persistence

    private static func load() -> Preferences {
        guard
            let data = UserDefaults.standard.data(forKey: defaultsKey),
            var prefs = try? JSONDecoder().decode(Preferences.self, from: data)
        else { return Preferences() }

        // Migration v1: earlier builds defaulted pattern to .verticalStripes.
        // Adaptive Text is a better default now that the shader uses a
        // contrast-reduction base for all modes; bump existing users exactly
        // once so the new default actually lands for them.
        let migratedKey = "com.pixelveil.migrated.v1"
        if !UserDefaults.standard.bool(forKey: migratedKey) {
            if prefs.pattern == .verticalStripes {
                prefs.pattern = .adaptiveText
            }
            UserDefaults.standard.set(true, forKey: migratedKey)
        }
        return prefs
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        UserDefaults.standard.set(data, forKey: Self.defaultsKey)
    }

    // MARK: Convenience mutators

    func settings(for displayID: UInt32) -> DisplaySettings? {
        displays.first(where: { $0.id == displayID })
    }

    func upsertDisplay(_ newValue: DisplaySettings) {
        if let idx = displays.firstIndex(where: { $0.id == newValue.id }) {
            displays[idx] = newValue
        } else {
            displays.append(newValue)
        }
    }

    func addOrUpdateRule(_ rule: AppRule) {
        if let idx = appRules.firstIndex(where: { $0.bundleIdentifier == rule.bundleIdentifier }) {
            appRules[idx] = rule
        } else {
            appRules.append(rule)
        }
    }

    func removeRule(id: UUID) {
        appRules.removeAll { $0.id == id }
    }
}
