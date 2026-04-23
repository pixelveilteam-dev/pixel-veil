//
//  UpdateBanner.swift
//  Pixel Veil
//
//  Shown at the top of the main window detail column when the
//  UpdateChecker has found a newer release. Purple/accent-tinted strip
//  with a download SF Symbol, version tag, primary "Update" button that
//  opens the release page, and a dismiss button.
//

import AppKit
import SwiftUI

struct UpdateBanner: View {
    @ObservedObject var checker: UpdateChecker

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.22))
                    .frame(width: 26, height: 26)
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text("Update available — Pixel Veil \(checker.latestVersion ?? "?")")
                    .font(.system(size: 12.5, weight: .semibold))
                Text("You're on \(AppInfo.version). Open the release page to grab the new DMG.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer()

            Button("View update") {
                if let url = checker.releasePageURL {
                    NSWorkspace.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)

            Button {
                checker.dismissed = true
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                    .padding(4)
            }
            .buttonStyle(.plain)
            .help("Dismiss")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            LinearGradient(
                colors: [Color.accentColor.opacity(0.14), Color.accentColor.opacity(0.05)],
                startPoint: .leading, endPoint: .trailing
            )
        )
        .overlay(Divider(), alignment: .bottom)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}
