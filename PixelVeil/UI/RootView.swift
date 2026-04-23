//
//  RootView.swift
//  Pixel Veil
//
//  The top-level split view: sidebar + detail. The detail area shows whichever
//  section the user has selected. The title bar is hidden (handled by
//  windowStyle(.hiddenTitleBar)) and we draw our own centered title to match
//  the reference design.
//

import SwiftUI

struct RootView: View {
    @State private var section: SidebarSection = .overview
    @State private var showFirstRun: Bool = !FirstRun.done
    @EnvironmentObject var settings: SettingsStore

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $section)
                .navigationSplitViewColumnWidth(min: 220, ideal: 240, max: 280)
        } detail: {
            ZStack(alignment: .top) {
                Color(nsColor: .windowBackgroundColor)
                    .ignoresSafeArea()
                VStack(spacing: 0) {
                    TitleBar(title: titleFor(section))
                    ScrollView {
                        Group {
                            switch section {
                            case .overview:    OverviewView(section: $section)
                            case .privacy:     PrivacyModeView()
                            case .displays:    DisplaysView()
                            case .automation:  AutomationView()
                            case .hotkeys:     HotkeysView()
                            case .permissions: PermissionsView()
                            case .about:       AboutView()
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 24)
                    }
                }
            }
        }
        .navigationSplitViewStyle(.balanced)
        .sheet(isPresented: $showFirstRun) {
            FirstRunView(isPresented: $showFirstRun)
                .environmentObject(settings)
        }
    }

    private func titleFor(_ s: SidebarSection) -> String {
        s == .overview ? "Pixel Veil" : s.title
    }
}

private struct TitleBar: View {
    let title: String
    var body: some View {
        ZStack {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
        }
        .frame(maxWidth: .infinity)
        .frame(height: 44)
        // Opaque window-tinted background — `.ultraThinMaterial` let scrolled
        // content (especially the blue slider fill) bleed through and read as
        // a random horizontal line.
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
