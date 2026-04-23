//
//  MenuBarPopover.swift
//  Pixel Veil
//
//  SwiftUI content for the menu bar popover: master toggle, strength slider,
//  and a short action list matching the reference design.
//

import SwiftUI
import AppKit

struct MenuBarPopover: View {
    @ObservedObject var settings: SettingsStore
    @ObservedObject var overlay: OverlayController

    var openMainWindow: () -> Void
    var openSettings: () -> Void
    var checkPermissions: () -> Void
    var quit: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            slider.padding(.horizontal, 16).padding(.vertical, 14)
            Divider()
            actions
        }
        .frame(width: 300)
    }

    private var header: some View {
        HStack {
            Text("Pixel Veil")
                .font(.system(size: 15, weight: .semibold))
            StatusLabel(
                text: settings.isEnabled ? "Active" : "Inactive",
                color: settings.isEnabled ? .green : .secondary
            )
            Spacer()
            Toggle("", isOn: $settings.isEnabled)
                .labelsHidden()
                .toggleStyle(.switch)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var slider: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Privacy Strength")
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                Text("\(Int(settings.strength * 100))%")
                    .font(.system(size: 12, weight: .semibold).monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Slider(value: $settings.strength, in: 0.0...1.0)
        }
    }

    private var actions: some View {
        VStack(spacing: 0) {
            actionRow("Quick Toggle", trailing: HotkeyTranslation.displayString(settings.hotkey)) {
                settings.isEnabled.toggle()
            }
            actionRow("Open Pixel Veil…", action: openMainWindow)
            actionRow("Settings…", action: openSettings)
            Divider().padding(.vertical, 4)
            actionRow("Check Permissions", action: checkPermissions)
            Divider().padding(.vertical, 4)
            actionRow("Quit Pixel Veil", destructive: true, action: quit)
        }
        .padding(.vertical, 6)
    }

    private func actionRow(_ label: String,
                           trailing: String? = nil,
                           destructive: Bool = false,
                           action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(label)
                    .font(.system(size: 13))
                    .foregroundStyle(destructive ? Color.primary : .primary)
                Spacer()
                if let trailing = trailing {
                    Text(trailing)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 7)
            .contentShape(Rectangle())
        }
        .buttonStyle(MenuRowButtonStyle())
    }
}

private struct MenuRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                configuration.isPressed
                    ? Color.accentColor.opacity(0.15)
                    : Color.clear
            )
    }
}
