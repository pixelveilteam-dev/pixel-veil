//
//  SidebarView.swift
//  Pixel Veil
//
//  macOS-style source list. Uses `List` with `.sidebar` style so it picks up
//  the system vibrancy + selection highlighting automatically.
//

import SwiftUI

enum SidebarSection: String, CaseIterable, Identifiable {
    case overview, privacy, displays, automation, hotkeys, permissions, about

    var id: String { rawValue }
    var title: String {
        switch self {
        case .overview:    return "Overview"
        case .privacy:     return "Privacy Mode"
        case .displays:    return "Displays"
        case .automation:  return "Automation"
        case .hotkeys:     return "Hotkeys"
        case .permissions: return "Permissions"
        case .about:       return "About"
        }
    }
    var symbol: String {
        switch self {
        case .overview:    return "house"
        case .privacy:     return "shield.lefthalf.filled"
        case .displays:    return "display"
        case .automation:  return "clock"
        case .hotkeys:     return "keyboard"
        case .permissions: return "lock"
        case .about:       return "info.circle"
        }
    }
}

struct SidebarView: View {
    @Binding var selection: SidebarSection

    var body: some View {
        VStack(spacing: 0) {
            AppHeader()
                .padding(.top, 14)
                .padding(.horizontal, 12)
                .padding(.bottom, 10)

            List(selection: $selection) {
                ForEach(SidebarSection.allCases.filter { $0 != .about }) { s in
                    Label(s.title, systemImage: s.symbol)
                        .tag(s)
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)

            Spacer(minLength: 0)

            Button {
                selection = .about
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle")
                    Text("About Pixel Veil")
                }
                .font(.system(size: 13, weight: .medium))
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(nsColor: .controlBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color.black.opacity(0.08), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .padding(12)
        }
    }
}

private struct AppHeader: View {
    var body: some View {
        HStack(spacing: 12) {
            AppIconView(size: 52, cornerRadius: 12)

            VStack(alignment: .leading, spacing: 2) {
                Text("Pixel Veil")
                    .font(.system(size: 14, weight: .semibold))
                Text("Version \(AppInfo.version)")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.6))
        )
    }
}
