#!/usr/bin/env swift
//
//  make-app-icon.swift
//  Composites the bare Pixel Veil mark onto a rounded-square purple gradient
//  canvas so the resulting PNG feels native alongside Apple's app icons.
//  Output is a 1024×1024 PNG ready for `iconutil -c icns`.
//
//  usage: swift make-app-icon.swift <mark-source.png> <output.png>
//

import AppKit
import CoreGraphics
import Foundation

let args = CommandLine.arguments
guard args.count == 3 else {
    FileHandle.standardError.write("usage: make-app-icon.swift <mark-source.png> <output.png>\n".data(using: .utf8)!)
    exit(2)
}
let src = URL(fileURLWithPath: args[1])
let dst = URL(fileURLWithPath: args[2])

let size: CGFloat = 1024
let canvas = CGSize(width: size, height: size)

// Apple's macOS icon template uses a superellipse with a specific corner
// radius ~= 0.223 × icon side. We match that so the icon nests correctly
// with system icons in the Dock.
let cornerRadius: CGFloat = size * 0.223
// Inset 10 % on each side so the content doesn't touch the corners — Apple
// reserves roughly that much safe area for the drop-shadow rim.
let contentInset: CGFloat = size * 0.10

guard let mark = NSImage(contentsOf: src),
      let markCG = mark.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
    FileHandle.standardError.write("failed to load mark image\n".data(using: .utf8)!)
    exit(1)
}

let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: Int(size),
    pixelsHigh: Int(size),
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 32
)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let ctx = NSGraphicsContext.current!.cgContext

// --- Rounded-square purple gradient backing ---
let cs = CGColorSpace(name: CGColorSpace.sRGB)!
let backColors = [
    CGColor(red: 0.60, green: 0.51, blue: 1.0, alpha: 1),   // light lavender top
    CGColor(red: 0.42, green: 0.31, blue: 0.90, alpha: 1),  // mid
    CGColor(red: 0.30, green: 0.21, blue: 0.78, alpha: 1),  // deep purple bottom
] as CFArray
let backGradient = CGGradient(colorsSpace: cs, colors: backColors, locations: [0, 0.55, 1])!

ctx.saveGState()
let squircle = CGPath(
    roundedRect: CGRect(origin: .zero, size: canvas),
    cornerWidth: cornerRadius,
    cornerHeight: cornerRadius,
    transform: nil
)
ctx.addPath(squircle)
ctx.clip()
ctx.drawLinearGradient(backGradient,
                       start: CGPoint(x: 0, y: size),
                       end:   CGPoint(x: 0, y: 0),
                       options: [])

// --- Subtle specular highlight at the top (makes it feel glassy) ---
let highlight = [
    CGColor(red: 1, green: 1, blue: 1, alpha: 0.25),
    CGColor(red: 1, green: 1, blue: 1, alpha: 0.0),
] as CFArray
let hg = CGGradient(colorsSpace: cs, colors: highlight, locations: [0, 1])!
ctx.drawRadialGradient(
    hg,
    startCenter: CGPoint(x: size / 2, y: size),
    startRadius: 0,
    endCenter:   CGPoint(x: size / 2, y: size),
    endRadius:   size * 0.55,
    options: []
)

// --- Composite the mark, centred with safe-area inset ---
let markRect = CGRect(
    x: contentInset,
    y: contentInset,
    width: size - 2 * contentInset,
    height: size - 2 * contentInset
)
ctx.saveGState()
// Subtle drop shadow behind the mark for depth.
ctx.setShadow(offset: CGSize(width: 0, height: -size * 0.015),
              blur: size * 0.035,
              color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.25))
ctx.draw(markCG, in: markRect)
ctx.restoreGState()

// --- Crisp inner rim (Apple uses a 1–2px lighter inner stroke) ---
ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.15))
ctx.setLineWidth(2)
let rimRect = CGRect(origin: .zero, size: canvas).insetBy(dx: 1, dy: 1)
let rim = CGPath(
    roundedRect: rimRect,
    cornerWidth: cornerRadius - 1,
    cornerHeight: cornerRadius - 1,
    transform: nil
)
ctx.addPath(rim)
ctx.strokePath()

ctx.restoreGState()  // release squircle clip

NSGraphicsContext.restoreGraphicsState()

guard let data = rep.representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write("failed to encode PNG\n".data(using: .utf8)!)
    exit(1)
}
try data.write(to: dst)
FileHandle.standardOutput.write("wrote \(dst.path)\n".data(using: .utf8)!)
