//
//  HotkeysView.swift
//  Pixel Veil
//

import SwiftUI

struct HotkeysView: View {
    @EnvironmentObject var settings: SettingsStore

    var body: some View {
        VStack(spacing: 16) {
            Card {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Toggle Privacy Mode")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Press this combo from anywhere in the system to turn Privacy Mode on or off.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    HotkeyRecorder(hotkey: $settings.hotkey)
                }
            }

            Card {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Tips")
                        .font(.system(size: 13, weight: .semibold))
                    Label("Combos without a modifier won't be accepted by the system.",
                          systemImage: "info.circle")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Label("If nothing happens, another app may have claimed the same shortcut.",
                          systemImage: "exclamationmark.triangle")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.top, 16)
    }
}
