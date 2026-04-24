//
//  PatternRenderer.swift
//  Pixel Veil
//
//  A CPU renderer used for the in-window Live Preview. The overlay itself uses
//  the Metal path; this fallback draws the same five patterns into a CGImage so
//  we can display them with a plain SwiftUI `Image` — no Metal view inside a
//  SwiftUI layout, which keeps preview hit-testing and screenshots simple.
//

import CoreGraphics
import Foundation

enum PatternRenderer {
    /// Produces a tileable mask image. Black alpha = "pixels off" regions.
    static func makeMaskImage(pattern: PatternMode,
                              strength: Double,
                              density: Double,
                              size: CGSize) -> CGImage? {
        let width  = max(1, Int(size.width))
        let height = max(1, Int(size.height))
        let cs = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: cs,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        // Clear.
        ctx.setFillColor(CGColor(gray: 0, alpha: 0))
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))

        let pitch = max(2, Int(round(24 - 21 * density)))
        let alpha = CGFloat(max(0, min(1, strength)))
        ctx.setFillColor(CGColor(gray: 0, alpha: alpha))

        switch pattern {
        case .verticalStripes:
            var x = 0
            while x < width {
                ctx.fill(CGRect(x: x, y: 0, width: pitch, height: height))
                x += pitch * 2
            }
        case .horizontalLines:
            var y = 0
            while y < height {
                ctx.fill(CGRect(x: 0, y: y, width: width, height: pitch))
                y += pitch * 2
            }
        case .checkerboard:
            var row = 0
            var y = 0
            while y < height {
                var x = (row % 2 == 0) ? 0 : pitch
                while x < width {
                    ctx.fill(CGRect(x: x, y: y, width: pitch, height: pitch))
                    x += pitch * 2
                }
                y += pitch
                row += 1
            }
        case .adaptiveText:
            let fine = max(1, pitch / 2)
            var x = 0
            while x < width {
                ctx.fill(CGRect(x: x, y: 0, width: fine, height: height))
                x += fine * 2
            }
        case .custom:
            // Diagonal hatch.
            for i in stride(from: -height, to: width, by: pitch * 2) {
                ctx.move(to: CGPoint(x: i, y: 0))
                ctx.addLine(to: CGPoint(x: i + height, y: height))
            }
            ctx.setStrokeColor(CGColor(gray: 0, alpha: alpha))
            ctx.setLineWidth(CGFloat(pitch))
            ctx.strokePath()
        }

        return ctx.makeImage()
    }

}
