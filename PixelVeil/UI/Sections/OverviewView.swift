//
//  OverviewView.swift
//  Pixel Veil
//
//  The "home" dashboard. A two-column layout: the hero Privacy Mode card +
//  pattern controls on the left, and compact utility cards on the right.
//

import SwiftUI

struct OverviewView: View {
    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var displays: DisplayManager
    @EnvironmentObject var permissions: PermissionsManager
    @EnvironmentObject var overlay: OverlayController
    /// Binding back to RootView's selected sidebar section, so sidecar cards
    /// can navigate the user into the full page for that topic.
    @Binding var section: SidebarSection

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Left column — hero + pattern. Live preview + schedule live on
            // their dedicated pages (Privacy Mode + Automation).
            VStack(spacing: 16) {
                privacyHero
                pattern
            }
            .frame(maxWidth: .infinity)

            // Right column — sidecars. Each is a real navigation button that
            // jumps to its full-page section in the sidebar.
            VStack(spacing: 16) {
                navCard(target: .displays)    { displaysCard }
                navCard(target: .hotkeys)     { hotkeyCard }
                navCard(target: .permissions) { permissionsCard }
            }
            .frame(width: 320)
        }
        .padding(.top, 16)
    }

    /// Wraps a sidecar card in a plain Button that navigates to the matching
    /// sidebar section. Keeps the card's visual design intact (Card already
    /// draws its own rounded background) while letting the whole surface be
    /// clickable.
    @ViewBuilder
    private func navCard<V: View>(target: SidebarSection, @ViewBuilder content: () -> V) -> some View {
        Button {
            section = target
        } label: {
            content()
        }
        .buttonStyle(.plain)
    }

    // MARK: Hero

    private var privacyHero: some View {
        // IMPORTANT: wrap in a single VStack so Card's `.padding` /
        // `.background` modifiers apply once to the whole thing. Multiple
        // siblings inside Card's ViewBuilder make SwiftUI's modifier
        // application repeat per-child — the result is three stacked cards
        // with visible gaps between them.
        Card {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 16) {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.accentColor.opacity(0.18))
                        .frame(width: 56, height: 56)
                        .overlay(
                            Image(systemName: "shield.lefthalf.filled")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundStyle(Color.accentColor)
                        )

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Privacy Mode")
                            .font(.system(size: 17, weight: .semibold))
                        StatusLabel(
                            text: settings.isEnabled ? "Active" : "Inactive",
                            color: settings.isEnabled ? .green : .secondary
                        )
                        if overlay.forcedOn && !settings.isEnabled {
                            StatusLabel(text: "Forced on by rule", color: .blue)
                        } else if overlay.forcedOff && settings.isEnabled {
                            StatusLabel(text: "Paused by rule", color: .orange)
                        }
                        Text(subtitle)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                    Toggle("", isOn: $settings.isEnabled)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .scaleEffect(1.05)
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Privacy Strength")
                            .font(.system(size: 13, weight: .semibold))
                        Spacer()
                        Text("\(Int(settings.strength * 100))%")
                            .font(.system(size: 13, weight: .semibold).monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    Text("Higher strength increases privacy by masking more pixels.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Slider(value: $settings.strength, in: 0.0...1.0)
                    HStack {
                        ForEach([20, 40, 60, 80, 100], id: \.self) { v in
                            Text("\(v)%")
                                .font(.system(size: 10))
                                .foregroundStyle(.tertiary)
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
        }
    }

    private var subtitle: String {
        settings.isEnabled
            ? "A contrast-reduction veil is compositing over your displays. Side viewers hit a lower contrast floor than you do head-on."
            : "Turn on Privacy Mode to apply the overlay to your displays."
    }

    // MARK: Pattern

    private var pattern: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                Text("Pattern Mode")
                    .font(.system(size: 13, weight: .semibold))
                Text("Choose the overlay pattern to apply.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                // Show every pattern so the Overview picker always reflects the
                // current selection — otherwise picking Horizontal Lines on the
                // Privacy Mode page would show as nothing-selected here.
                PatternPicker(selection: $settings.pattern)
            }
        }
    }

    // MARK: Schedule row

    // MARK: Sidecar cards

    private var displaysCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                Text("Displays")
                    .font(.system(size: 13, weight: .semibold))
                ForEach(displays.screens, id: \.self) { screen in
                    HStack(spacing: 12) {
                        Image(systemName: screen == NSScreen.main ? "laptopcomputer" : "display")
                            .font(.system(size: 16))
                            .foregroundStyle(.secondary)
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(screen == NSScreen.main ? "Built-in Display" : DisplayManager.name(for: screen))
                                .font(.system(size: 12, weight: .medium))
                            Text(String(format: "%.0f × %.0f",
                                        screen.frame.width, screen.frame.height))
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                }
                HStack(spacing: 5) {
                    Text("Configure Displays")
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.accentColor)
            }
        }
    }

    private var hotkeyCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                Text("Global Hotkey")
                    .font(.system(size: 13, weight: .semibold))
                Text("Toggle Privacy Mode on or off.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                HotkeyRecorder(hotkey: $settings.hotkey)
            }
        }
    }

    private var permissionsCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                Text("Permissions")
                    .font(.system(size: 13, weight: .semibold))
                permissionRow("Accessibility", permissions.accessibility)
                permissionRow("Screen Recording", permissions.screenRecording)
            }
        }
    }

    private func permissionRow(_ label: String, _ state: PermissionState) -> some View {
        HStack(spacing: 10) {
            Image(systemName: state == .granted ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .font(.system(size: 15))
                .foregroundStyle(state == .granted ? .green : .orange)
            Text(label)
                .font(.system(size: 12, weight: .medium))
            Spacer()
            Text(state == .granted ? "Granted" : (state == .denied ? "Not granted" : "Unknown"))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
    }
}
