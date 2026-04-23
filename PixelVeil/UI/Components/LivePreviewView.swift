//
//  LivePreviewView.swift
//  Pixel Veil
//
//  Shows what Privacy Mode looks like compositing over a realistic desktop
//  scene — mock menu bar, an app window with text rows, and a dock. The user
//  can see at a glance how much head-on legibility they're giving up.
//
//  Wallpaper source:
//    1. If ~/Library/Application Support/PixelVeil/wallpaper.* exists, use it.
//    2. Otherwise fall back to a stylized gradient.
//
//  The CPU-side PatternRenderer composites the same mask the Metal overlay
//  draws, so the preview matches the actual effect.
//

import AppKit
import SwiftUI

struct LivePreviewView: View {
    @EnvironmentObject var settings: SettingsStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Live Preview")

            LaptopFrame {
                ZStack {
                    Wallpaper()
                    MockDesktopUI()
                    PatternOverlay(pattern: settings.pattern,
                                   strength: settings.strength,
                                   density: settings.density)
                        .opacity(settings.isEnabled ? 1 : 0.25)
                        .animation(.easeInOut(duration: 0.2), value: settings.pattern)
                        .animation(.easeInOut(duration: 0.2), value: settings.strength)
                        .animation(.easeInOut(duration: 0.2), value: settings.isEnabled)
                }
            }
            .frame(height: 260)

            Text("Preview shows an approximation. Actual pattern may vary by display.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }
}

// MARK: - Laptop frame

private struct LaptopFrame<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.black)
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
                    .padding(8)
                content
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .padding(8)
            }
            .aspectRatio(16.0/10.0, contentMode: .fit)

            Rectangle()
                .fill(LinearGradient(colors: [Color(white: 0.78), Color(white: 0.92)],
                                     startPoint: .top, endPoint: .bottom))
                .frame(height: 10)
                .overlay(
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.black.opacity(0.18))
                        .frame(width: 60, height: 4)
                )
                .clipShape(UnevenRoundedRectangle(
                    cornerRadii: .init(topLeading: 0, bottomLeading: 10,
                                       bottomTrailing: 10, topTrailing: 0)
                ))
        }
        .padding(.horizontal, 8)
    }
}

// MARK: - Wallpaper

private struct Wallpaper: View {
    var body: some View {
        ZStack {
            if let nsImage = WallpaperLoader.shared.image {
                Image(nsImage: nsImage)
                    .resizable()
                    .scaledToFill()
            } else {
                fallback
            }
            // A very subtle darkening wash so the mock UI sits calmly on top
            // regardless of which wallpaper is used. Keeps the "low-key"
            // macOS 26 aesthetic — nothing ever feels loud.
            LinearGradient(
                colors: [Color.black.opacity(0.18), Color.black.opacity(0.04), Color.black.opacity(0.12)],
                startPoint: .top, endPoint: .bottom
            )
        }
    }

    // macOS 26 vibes: muted, low-saturation pastel gradient with a soft
    // radial lift near the top. No punchy hues, nothing that reads as "candy".
    private var fallback: some View {
        ZStack {
            LinearGradient(
                stops: [
                    .init(color: Color(red: 0.24, green: 0.28, blue: 0.38), location: 0.00),
                    .init(color: Color(red: 0.38, green: 0.38, blue: 0.48), location: 0.40),
                    .init(color: Color(red: 0.55, green: 0.50, blue: 0.52), location: 0.75),
                    .init(color: Color(red: 0.68, green: 0.60, blue: 0.56), location: 1.00)
                ],
                startPoint: .top, endPoint: .bottom
            )
            RadialGradient(
                colors: [Color.white.opacity(0.08), Color.clear],
                center: .init(x: 0.5, y: 0.12),
                startRadius: 0, endRadius: 260
            )
        }
    }
}

// MARK: - Mock UI

private struct MockDesktopUI: View {
    var body: some View {
        VStack(spacing: 0) {
            // Menu bar
            HStack(spacing: 10) {
                Image(systemName: "apple.logo")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.white)
                Text("Safari").font(.system(size: 9, weight: .semibold))
                Text("File").font(.system(size: 9))
                Text("Edit").font(.system(size: 9))
                Text("View").font(.system(size: 9))
                Spacer()
                Image(systemName: "wifi").font(.system(size: 9))
                Image(systemName: "battery.100").font(.system(size: 9))
                Text("9:41 AM").font(.system(size: 9))
            }
            .foregroundStyle(.white.opacity(0.95))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.black.opacity(0.25))

            // Window with text rows — this is where the pattern's effect on
            // readability is most visible.
            MockWindow()
                .padding(.horizontal, 14)
                .padding(.top, 10)

            Spacer()

            // Dock
            HStack(spacing: 5) {
                ForEach(0..<7, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(LinearGradient(colors: [
                            Color.white.opacity(0.6), Color.white.opacity(0.2)
                        ], startPoint: .top, endPoint: .bottom))
                        .frame(width: 20, height: 20)
                        .overlay(
                            Image(systemName: Self.dockIcons[i])
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.9))
                        )
                }
            }
            .padding(6)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(.white.opacity(0.18))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(.white.opacity(0.25), lineWidth: 0.5)
                    )
            )
            .padding(.bottom, 8)
        }
    }

    private static let dockIcons = [
        "safari", "envelope.fill", "message.fill",
        "music.note", "photo.fill", "terminal.fill", "gearshape.fill"
    ]
}

private struct MockWindow: View {
    var body: some View {
        VStack(spacing: 0) {
            // Title bar
            HStack(spacing: 4) {
                Circle().fill(Color(red: 1.0, green: 0.38, blue: 0.36)).frame(width: 6, height: 6)
                Circle().fill(Color(red: 1.0, green: 0.75, blue: 0.29)).frame(width: 6, height: 6)
                Circle().fill(Color(red: 0.32, green: 0.78, blue: 0.33)).frame(width: 6, height: 6)
                Spacer()
                Text("Document.txt").font(.system(size: 8, weight: .medium))
                Spacer().frame(width: 18)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color.white.opacity(0.92))

            // Text body — fake lines of varying widths.
            VStack(alignment: .leading, spacing: 4) {
                ForEach(0..<9, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Color.black.opacity(0.72))
                        .frame(height: 3)
                        .frame(maxWidth: .infinity)
                        .padding(.trailing, Self.lineInsets[i % Self.lineInsets.count])
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.86))
        }
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .shadow(color: .black.opacity(0.3), radius: 6, y: 3)
    }

    private static let lineInsets: [CGFloat] = [0, 10, 30, 4, 60, 20, 0, 90, 14]
}

// MARK: - Pattern overlay

private struct PatternOverlay: View {
    let pattern: PatternMode
    let strength: Double
    let density: Double

    var body: some View {
        GeometryReader { geo in
            if let cg = PatternRenderer.makeMaskImage(
                pattern: pattern,
                strength: strength,
                density: density,
                size: CGSize(width: max(1, geo.size.width * 2),
                             height: max(1, geo.size.height * 2))
            ) {
                Image(decorative: cg, scale: 2.0)
                    .resizable()
                    .interpolation(.none)
                    .frame(width: geo.size.width, height: geo.size.height)
            }
        }
    }
}

// MARK: - Wallpaper loader

private final class WallpaperLoader {
    static let shared = WallpaperLoader()
    let image: NSImage?

    init() {
        let fm = FileManager.default
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("PixelVeil", isDirectory: true)
        let candidates = ["wallpaper.jpg", "wallpaper.jpeg", "wallpaper.png", "wallpaper.heic"]
        for name in candidates {
            if let url = base?.appendingPathComponent(name),
               fm.fileExists(atPath: url.path),
               let img = NSImage(contentsOf: url) {
                self.image = img
                return
            }
        }
        self.image = nil
    }
}
