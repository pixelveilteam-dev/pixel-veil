//
//  PermissionsView.swift
//  Pixel Veil
//

import SwiftUI

struct PermissionsView: View {
    @EnvironmentObject var permissions: PermissionsManager

    var body: some View {
        VStack(spacing: 16) {
            permissionCard(
                title: "Accessibility",
                subtitle: "Optional. Only required for app-rule automation that reads the frontmost app reliably in secure-input contexts.",
                state: permissions.accessibility,
                action: { permissions.requestAccessibility() }
            )
            permissionCard(
                title: "Screen Recording",
                subtitle: "Optional. Only required if Adaptive Text mode is enabled and shifts the pattern around text regions.",
                state: permissions.screenRecording,
                action: { permissions.requestScreenRecording() }
            )

            Card {
                Text("Pixel Veil's overlay itself does not require any permission. It runs as a transparent borderless window at the screen-saver layer.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.top, 16)
        .onAppear { permissions.refresh() }
    }

    private func permissionCard(title: String, subtitle: String,
                                state: PermissionState, action: @escaping () -> Void) -> some View {
        Card {
            HStack(alignment: .top, spacing: 16) {
                Image(systemName: state == .granted ? "checkmark.seal.fill" : "lock.shield")
                    .font(.system(size: 26))
                    .foregroundStyle(state == .granted ? .green : .orange)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.system(size: 14, weight: .semibold))
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack {
                        StatusLabel(
                            text: state == .granted ? "Granted"
                                 : state == .denied ? "Not granted" : "Unknown",
                            color: state == .granted ? .green : .orange
                        )
                        Spacer()
                        if state != .granted {
                            Button("Open Settings…", action: action)
                                .controlSize(.small)
                                .buttonStyle(.bordered)
                        }
                    }
                }
            }
        }
    }
}
