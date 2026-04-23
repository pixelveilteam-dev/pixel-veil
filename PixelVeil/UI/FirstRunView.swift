//
//  FirstRunView.swift
//  Pixel Veil
//
//  A Welcome / onboarding sheet shown once per install. Explains what the app
//  does, what it can't do (hardware privacy layers), and lets the user set the
//  initial hotkey and brightness-dim preference before seeing the main window.
//
//  Persistence: we store a single Bool in UserDefaults. Intentionally
//  separate from the main Preferences blob so a corrupted prefs file
//  doesn't resurrect the tour.
//

import SwiftUI

enum FirstRun {
    private static let key = "com.pixelveil.didCompleteFirstRun"
    static var done: Bool {
        get { UserDefaults.standard.bool(forKey: key) }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }
}

struct FirstRunView: View {
    @Binding var isPresented: Bool
    @EnvironmentObject var settings: SettingsStore

    @State private var page: Int = 0
    private let pages = 3

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                switch page {
                case 0: welcome.transition(.opacity)
                case 1: howItWorks.transition(.opacity)
                default: setup.transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: page)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 40)
            .padding(.top, 40)

            Divider()

            HStack {
                PageDots(count: pages, current: page)
                Spacer()
                if page > 0 {
                    Button("Back") { page -= 1 }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                }
                Button(page == pages - 1 ? "Get Started" : "Continue") {
                    if page == pages - 1 {
                        FirstRun.done = true
                        isPresented = false
                    } else {
                        page += 1
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
            }
            .padding(20)
        }
        .frame(width: 640, height: 500)
    }

    // MARK: Pages

    private var welcome: some View {
        VStack(spacing: 18) {
            if let illustration = AppImages.onboardingWelcome {
                Image(nsImage: illustration)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 180)
            } else {
                AppIconView(size: 120, cornerRadius: 26)
                    .shadow(color: .black.opacity(0.18), radius: 10, y: 5)
            }

            Text("Welcome to Pixel Veil")
                .font(.system(size: 26, weight: .semibold))

            Text("A privacy-screen utility for your Mac. Pixel Veil composites a subtle mask over your displays to make side-angle viewing harder for people sitting next to you.")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
        }
    }

    private var howItWorks: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 18) {
                Text("How it works")
                    .font(.system(size: 22, weight: .semibold))
                Spacer()
                if let illustration = AppImages.onboardingHow {
                    Image(nsImage: illustration)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 180)
                }
            }

            featureRow(icon: "eye.slash",
                       title: "Contrast-reduction veil",
                       body: "A mid-grey layer narrows your display's effective dynamic range. You stay above the reading threshold head-on; observers at an angle, whose contrast is already degraded, fall below it.")

            featureRow(icon: "sun.min",
                       title: "Forced brightness dimming",
                       body: "Privacy Mode lowers your panel brightness to amplify the effect. The original brightness is restored when you turn it off.")

            featureRow(icon: "exclamationmark.shield",
                       title: "What it isn't",
                       body: "macOS doesn't expose per-pixel hardware control. This is a software approximation — useful in public spaces, but not equivalent to a hardware privacy filter.")

            Spacer()
        }
    }

    private var setup: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Quick setup")
                .font(.system(size: 22, weight: .semibold))

            VStack(alignment: .leading, spacing: 12) {
                Text("Global shortcut").font(.system(size: 13, weight: .semibold))
                Text("Press a key combo you'll remember. Use it from anywhere to toggle Privacy Mode.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                HotkeyRecorder(hotkey: $settings.hotkey)
            }

            Divider().padding(.vertical, 4)

            Toggle(isOn: $settings.dimBrightness) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Force brightness down when active")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Lowers your display brightness automatically and restores it when turned off.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
            .toggleStyle(.switch)

            Spacer()
        }
    }

    private func featureRow(icon: String, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(Color.accentColor)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 13, weight: .semibold))
                Text(body)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct PageDots: View {
    let count: Int
    let current: Int
    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<count, id: \.self) { i in
                Circle()
                    .fill(i == current ? Color.accentColor : Color.secondary.opacity(0.35))
                    .frame(width: 6, height: 6)
            }
        }
    }
}
