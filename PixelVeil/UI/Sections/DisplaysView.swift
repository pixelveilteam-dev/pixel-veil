//
//  DisplaysView.swift
//  Pixel Veil
//
//  One card per attached display with per-display enable, strength override,
//  and pattern override. Changes flow straight into SettingsStore, which
//  OverlayController is already observing.
//

import SwiftUI
import AppKit

struct DisplaysView: View {
    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var displays: DisplayManager

    var body: some View {
        VStack(spacing: 16) {
            if displays.screens.isEmpty {
                Card {
                    Text("No displays detected.").foregroundStyle(.secondary)
                }
            } else {
                ForEach(displays.screens, id: \.self) { screen in
                    displayCard(screen: screen)
                }
            }
        }
        .padding(.top, 16)
    }

    private func displayCard(screen: NSScreen) -> some View {
        let id = DisplayManager.displayID(for: screen) ?? 0
        let binding = Binding<DisplaySettings>(
            get: {
                settings.settings(for: id) ?? DisplaySettings(
                    id: id,
                    name: DisplayManager.name(for: screen),
                    enabled: true
                )
            },
            set: { settings.upsertDisplay($0) }
        )
        return Card {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Image(systemName: screen == NSScreen.main ? "laptopcomputer" : "display")
                        .font(.system(size: 22))
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(binding.wrappedValue.name)
                            .font(.system(size: 14, weight: .semibold))
                        Text(String(format: "%.0f × %.0f @ %.0fx",
                                    screen.frame.width, screen.frame.height,
                                    screen.backingScaleFactor))
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: binding.enabled)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }

                Divider()

                HStack(alignment: .top, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Strength Override")
                            .font(.system(size: 12, weight: .semibold))
                        Toggle("Use per-display strength",
                               isOn: Binding(
                                get: { binding.wrappedValue.strengthOverride != nil },
                                set: { use in
                                    var v = binding.wrappedValue
                                    v.strengthOverride = use ? (v.strengthOverride ?? settings.strength) : nil
                                    binding.wrappedValue = v
                                }))
                        .toggleStyle(.checkbox)
                        if binding.wrappedValue.strengthOverride != nil {
                            Slider(value: Binding(
                                get: { binding.wrappedValue.strengthOverride ?? settings.strength },
                                set: { new in
                                    var v = binding.wrappedValue
                                    v.strengthOverride = new
                                    binding.wrappedValue = v
                                }), in: 0.0...1.0)
                        }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Pattern Override")
                            .font(.system(size: 12, weight: .semibold))
                        Picker("Pattern", selection: Binding(
                            get: { binding.wrappedValue.patternOverride ?? settings.pattern },
                            set: { new in
                                var v = binding.wrappedValue
                                v.patternOverride = new == settings.pattern ? nil : new
                                binding.wrappedValue = v
                            })) {
                            ForEach(PatternMode.allCases) { p in
                                Text(p.displayName).tag(p)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                    }
                }
            }
        }
    }
}
