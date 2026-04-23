//
//  PrivacyModeView.swift
//  Pixel Veil
//
//  Deeper controls for the overlay: all five pattern modes, density slider,
//  strength slider, and a larger live preview.
//

import SwiftUI

struct PrivacyModeView: View {
    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var overlay: OverlayController

    var body: some View {
        VStack(spacing: 16) {
            Card {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Enable Privacy Mode")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Master control for the screen overlay.")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: $settings.isEnabled)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }
            }

            Card {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Pattern")
                        .font(.system(size: 13, weight: .semibold))
                    PatternPicker(selection: $settings.pattern)

                    Divider().padding(.vertical, 2)

                    sliderRow(
                        label: "Privacy Strength",
                        description: "How much of the screen is masked per pattern cell.",
                        value: $settings.strength,
                        percent: true
                    )

                    sliderRow(
                        label: "Pattern Density",
                        description: "Finer patterns look smoother but may shimmer on sub-pixel layouts.",
                        value: $settings.density,
                        percent: true
                    )
                }
            }

            Card {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Force brightness down")
                                .font(.system(size: 13, weight: .semibold))
                            Text("Lowers your display brightness while Privacy Mode is active and restores it when turned off.")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer()
                        Toggle("", isOn: $settings.dimBrightness)
                            .labelsHidden()
                            .toggleStyle(.switch)
                    }
                    if settings.dimBrightness {
                        Divider()
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Target brightness")
                                    .font(.system(size: 12, weight: .semibold))
                                Spacer()
                                Text("\(Int(settings.dimTarget * 100))%")
                                    .font(.system(size: 12, weight: .semibold).monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                            Slider(value: $settings.dimTarget, in: 0.05...0.80)
                            Text("Lower values amplify the contrast-reduction effect but reduce head-on readability.")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Card {
                LivePreviewView()
            }
        }
        .padding(.top, 16)
    }

    private func sliderRow(label: String, description: String, value: Binding<Double>, percent: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label).font(.system(size: 13, weight: .semibold))
                Spacer()
                Text(percent ? "\(Int(value.wrappedValue * 100))%" : String(format: "%.2f", value.wrappedValue))
                    .font(.system(size: 13, weight: .semibold).monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Text(description)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Slider(value: value, in: 0.0...1.0)
        }
    }
}
