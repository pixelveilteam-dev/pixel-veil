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
    static let markOnly: NSImage = {
        let source = withText
        guard source.size.width > 0 else { return source }
        // Both logos use ~62 % of the vertical canvas for the glyph; we trim
        // a touch more (64 %) to shed the breathing room above the wordmark.
        let cropFrac: CGFloat = 0.64
        return cropTop(source, fraction: cropFrac)
    }()

    /// Loads a PNG from the app bundle's Resources folder.
    private static func load(_ name: String) -> NSImage? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "png"),
              let image = NSImage(contentsOf: url) else { return nil }
        return image
    }

    /// A monochrome silhouette of the mark, suitable for use as an NSImage
    /// template in the menu bar. We take the shape from the transparent
    /// logo's alpha channel and fill it solid black; marking the NSImage as
    /// template makes AppKit tint it to match the menu bar appearance in
    /// both light and dark mode — no need for separate assets.
    ///
    /// The output canvas matches the source's aspect ratio so the
    /// monitor+shield doesn't get squashed. Paired with NSStatusItem's
    /// `variableLength` the status item resizes to fit.
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
