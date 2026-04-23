//
//  AppImages.swift
//  Pixel Veil
//
//  Loads the app's bundled logo PNGs and exposes convenience slices:
//    * `markOnly`   — just the monitor+shield glyph, text cropped out. Used
//                     everywhere we want an icon alongside text (sidebar,
//                     menu bar, About hero).
//    * `withText`   — the full composed logo including the "Pixel Veil"
//                     wordmark. Used for the first-run welcome splash and
//                     the Dock icon.
//
//  The project ships two PNGs (full + transparent) and we prefer the
//  transparent one so the logo composits cleanly over any background tint.
//  Both images have identical composition — monitor+shield in the top ~62 %,
//  wordmark in the bottom ~38 %, all on a square canvas.
//

import AppKit
import SwiftUI

enum AppImages {
    /// The complete logo (mark + wordmark). Prefers the transparent PNG so it
    /// blends with the sheet / card background we put it on.
    static let withText: NSImage = {
        if let img = load("logo-transparent") { return img }
        if let img = load("logo-full") { return img }
        return NSImage()
    }()

    /// Just the monitor + shield glyph, wordmark cropped out. Ideal for any
    /// context where we already show the name "Pixel Veil" as text, so we
    /// avoid drawing the wordmark twice.
    ///
    /// Prefers the standalone `logo-mark.png` (no text, square canvas) if
    /// present. Falls back to cropping the wordmark off the composed logo
    /// for older bundles where only the full logo was shipped.
    static let markOnly: NSImage = {
        if let img = load("logo-mark") { return img }
        let source = withText
        guard source.size.width > 0 else { return source }
        return cropTop(source, fraction: 0.64)
    }()

    /// Illustration for the First-Run welcome screen — shows the "what side
    /// viewers see" concept. Optional asset; absent bundles show nothing.
    static let onboardingWelcome: NSImage? = load("onboard-welcome")

    /// Illustration for the First-Run "How it works" screen — component flow.
    static let onboardingHow: NSImage? = load("onboard-how")

    /// Loads a PNG from the app bundle's Resources folder.
    private static func load(_ name: String) -> NSImage? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "png"),
              let image = NSImage(contentsOf: url) else { return nil }
        return image
    }

    /// Full-colour version of the mark sized for the menu bar. We do NOT flag
    /// it as a template image — the user prefers the natural purple/black
    /// palette to appear literally, instead of being flattened to monochrome
    /// by AppKit's template tinting. Active state overlays a small filled
    /// badge dot in the upper-right corner.
    ///
    /// Output aspect matches the source so the monitor+shield never squashes;
    /// pair with NSStatusItem's `variableLength` so the bar makes room.
    static func menuBarIcon(height: CGFloat = 18, withBadge: Bool = false) -> NSImage {
        let source = markOnly
        let srcSize = source.size
        let aspect: CGFloat = srcSize.height > 0 ? (srcSize.width / srcSize.height) : 1.0
        let target = NSSize(width: max(height, height * aspect), height: height)

        let img = NSImage(size: target, flipped: false) { _ in
            guard let ctx = NSGraphicsContext.current?.cgContext,
                  let cg = source.cgImage(forProposedRect: nil,
                                          context: NSGraphicsContext.current,
                                          hints: nil)
            else { return false }
            // Draw the logo as-is with its real colours.
            ctx.draw(cg, in: CGRect(origin: .zero, size: target))

            if withBadge {
                let dotR: CGFloat = max(1.8, height * 0.18)
                let dotX = target.width  - dotR * 2
                let dotY = target.height - dotR * 2
                ctx.setFillColor(NSColor.systemPurple.cgColor)
                ctx.fillEllipse(in: CGRect(x: dotX, y: dotY,
                                           width: dotR * 2, height: dotR * 2))
            }
            return true
        }
        // NOT a template — we want the mark's own colours to show.
        img.isTemplate = false
        return img
    }

    /// Legacy monochrome silhouette. Kept around for callers that want a
    /// template-tinted variant; current menu bar uses `menuBarIcon` instead.
    static func menuBarSilhouette(height: CGFloat = 18, withBadge: Bool = false) -> NSImage {
        let source = markOnly
        let srcSize = source.size
        let aspect: CGFloat = srcSize.height > 0 ? (srcSize.width / srcSize.height) : 1.0
        let target = NSSize(width: max(height, height * aspect), height: height)

        let img = NSImage(size: target, flipped: false) { _ in
            guard let ctx = NSGraphicsContext.current?.cgContext,
                  let cg = source.cgImage(forProposedRect: nil,
                                          context: NSGraphicsContext.current,
                                          hints: nil)
            else { return false }

            ctx.saveGState()
            ctx.clip(to: CGRect(origin: .zero, size: target), mask: cg)
            ctx.setFillColor(NSColor.black.cgColor)
            ctx.fill(CGRect(origin: .zero, size: target))
            ctx.restoreGState()

            if withBadge {
                let dotR: CGFloat = max(1.8, height * 0.18)
                let dotX = target.width  - dotR * 2
                let dotY = target.height - dotR * 2
                ctx.setFillColor(NSColor.black.cgColor)
                ctx.fillEllipse(in: CGRect(x: dotX, y: dotY,
                                           width: dotR * 2, height: dotR * 2))
            }
            return true
        }
        img.isTemplate = true
        return img
    }

    /// Returns a new NSImage containing just the top `fraction` of the source,
    /// preserving aspect and using a square output canvas centered around the
    /// cropped glyph. We render into a bitmap context at 2× for Retina.
    private static func cropTop(_ image: NSImage, fraction: CGFloat) -> NSImage {
        let rect = NSRect(origin: .zero, size: image.size)
        let cropHeight = image.size.height * fraction
        let srcRect = NSRect(x: 0,
                             y: image.size.height - cropHeight,
                             width: image.size.width,
                             height: cropHeight)

        let outSize = NSSize(width: image.size.width, height: cropHeight)
        let out = NSImage(size: outSize)
        out.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: outSize),
                   from: srcRect,
                   operation: .sourceOver,
                   fraction: 1.0)
        out.unlockFocus()
        _ = rect // silence unused warning on release builds
        return out
    }
}

/// Small SwiftUI convenience that renders the mark inside a rounded square of
/// the requested size, matching the previous gradient-square placeholder.
struct AppIconView: View {
    var size: CGFloat = 36
    var cornerRadius: CGFloat?
    var body: some View {
        Image(nsImage: AppImages.markOnly)
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius ?? (size * 0.22),
                                        style: .continuous))
    }
}
