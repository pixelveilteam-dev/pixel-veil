#!/usr/bin/env swift
//
//  make-dmg-background.swift
//  Generates a 640×400 PNG background image for the Pixel Veil DMG.
//  Called from make-dmg.sh at build time.
//
//  Layout: soft purple-black gradient, Pixel Veil logo mark top-centre,
//  an arrow pointing from the left icon slot to the right Applications
//  slot, minimal wordmark. No fonts required beyond system-default
//  rendering.
//

import AppKit
import CoreGraphics
import Foundation

let args = CommandLine.arguments
guard args.count == 3 else {
    FileHandle.standardError.write("usage: make-dmg-background.swift <logo-mark.png> <output.png>\n".data(using: .utf8)!)
    exit(2)
}
let logoURL   = URL(fileURLWithPath: args[1])
let outputURL = URL(fileURLWithPath: args[2])

let size = CGSize(width: 640, height: 400)
let logo = NSImage(contentsOf: logoURL)

let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: Int(size.width),
    pixelsHigh: Int(size.height),
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 32
)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
let ctx = NSGraphicsContext.current!.cgContext

// --- Background gradient ---
let colors = [
    CGColor(red: 0.075, green: 0.055, blue: 0.135, alpha: 1),  // deep purple-black
    CGColor(red: 0.125, green: 0.085, blue: 0.220, alpha: 1),
    CGColor(red: 0.085, green: 0.065, blue: 0.155, alpha: 1),
] as CFArray
let cs = CGColorSpace(name: CGColorSpace.sRGB)!
let gradient = CGGradient(colorsSpace: cs, colors: colors, locations: [0, 0.55, 1])!
ctx.drawLinearGradient(gradient,
                       start: CGPoint(x: 0, y: size.height),
                       end:   CGPoint(x: size.width, y: 0),
                       options: [])

// --- Soft ambient glow (radial, centre-top) ---
let glowColors = [
    CGColor(red: 0.55, green: 0.42, blue: 1.0, alpha: 0.35),
    CGColor(red: 0.55, green: 0.42, blue: 1.0, alpha: 0.0),
] as CFArray
let glow = CGGradient(colorsSpace: cs, colors: glowColors, locations: [0, 1])!
ctx.drawRadialGradient(
    glow,
    startCenter: CGPoint(x: size.width / 2, y: size.height - 40),
    startRadius: 0,
    endCenter:   CGPoint(x: size.width / 2, y: size.height - 40),
    endRadius:   360,
    options: []
)

// --- Subtle diagonal grid (like the site hero) ---
ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.035))
ctx.setLineWidth(1)
let gridStep: CGFloat = 32
for x in stride(from: 0.0, through: size.width, by: gridStep) {
    ctx.move(to: CGPoint(x: x, y: 0))
    ctx.addLine(to: CGPoint(x: x, y: size.height))
}
for y in stride(from: 0.0, through: size.height, by: gridStep) {
    ctx.move(to: CGPoint(x: 0, y: y))
    ctx.addLine(to: CGPoint(x: size.width, y: y))
}
ctx.strokePath()

// --- Logo top-centre, modest size ---
if let logo = logo,
   let cg = logo.cgImage(forProposedRect: nil, context: NSGraphicsContext.current, hints: nil) {
    let logoSize: CGFloat = 88
    let rect = CGRect(x: (size.width - logoSize) / 2,
                      y: size.height - logoSize - 30,
                      width: logoSize, height: logoSize)
    // Drop shadow
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -6),
                  blur: 24,
                  color: CGColor(red: 0.45, green: 0.32, blue: 1.0, alpha: 0.6))
    ctx.draw(cg, in: rect)
    ctx.restoreGState()
}

// --- Text: "Drag Pixel Veil into Applications to install" ---
let para = NSMutableParagraphStyle()
para.alignment = .center
let titleAttrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 18, weight: .semibold),
    .foregroundColor: NSColor.white,
    .paragraphStyle: para,
]
let subAttrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 12, weight: .regular),
    .foregroundColor: NSColor(white: 1, alpha: 0.55),
    .paragraphStyle: para,
]

let title = NSAttributedString(string: "Install Pixel Veil",
                               attributes: titleAttrs)
let sub   = NSAttributedString(string: "Drag the app icon into the Applications folder",
                               attributes: subAttrs)

// Position the text between the two icon slots (icons live at y~110 in DMG
// layout which maps to y=size.height-110 in our bottom-up coordinate system
// for drawing, but NSAttributedString draws top-down respecting the current
// context orientation — we want the text just above the icons).
title.draw(with: CGRect(x: 0, y: 200, width: size.width, height: 26),
           options: [.usesLineFragmentOrigin])
sub.draw(with:   CGRect(x: 0, y: 178, width: size.width, height: 20),
         options: [.usesLineFragmentOrigin])

// --- Arrow between icon slots (decorative) ---
// DMG icons typically sit at (160, 200) and (480, 200). Bridge them with a
// subtle chevron so the "drag-to-install" gesture reads at a glance.
ctx.setStrokeColor(CGColor(red: 0.65, green: 0.52, blue: 1.0, alpha: 0.75))
ctx.setLineWidth(2)
ctx.setLineCap(.round)
let arrowY: CGFloat = 140
let arrowStart = CGPoint(x: 230, y: arrowY)
let arrowEnd   = CGPoint(x: 410, y: arrowY)
ctx.move(to: arrowStart)
ctx.addLine(to: arrowEnd)
// Arrowhead
ctx.move(to: CGPoint(x: arrowEnd.x - 10, y: arrowY + 7))
ctx.addLine(to: arrowEnd)
ctx.addLine(to: CGPoint(x: arrowEnd.x - 10, y: arrowY - 7))
ctx.strokePath()

NSGraphicsContext.restoreGraphicsState()

// --- Write PNG ---
let data = bitmap.representation(using: .png, properties: [:])!
try data.write(to: outputURL)
FileHandle.standardOutput.write("wrote \(outputURL.path)\n".data(using: .utf8)!)
