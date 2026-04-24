//
//  WindowTargetProvider.swift
//  Pixel Veil
//
//  Reads visible app window bounds from the window server so an app rule can
//  veil only that app instead of the entire display.
//

import AppKit
import CoreGraphics

enum WindowTargetProvider {
    static func visibleWindowFrames(bundleIdentifier: String,
                                    screens: [NSScreen],
                                    padding: CGFloat = 3) -> [CGRect] {
        let pids = Set(NSRunningApplication
            .runningApplications(withBundleIdentifier: bundleIdentifier)
            .map(\.processIdentifier))
        guard !pids.isEmpty else { return [] }

        guard let rawList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements],
                                                       kCGNullWindowID) as? [[String: Any]] else {
            return []
        }

        return rawList.compactMap { info -> CGRect? in
            guard
                let pid = info[kCGWindowOwnerPID as String] as? pid_t,
                pids.contains(pid),
                let layer = info[kCGWindowLayer as String] as? Int,
                layer == 0,
                let alpha = info[kCGWindowAlpha as String] as? Double,
                alpha > 0.02,
                let boundsDict = info[kCGWindowBounds as String] as? [String: Any],
                let quartzBounds = CGRect(dictionaryRepresentation: boundsDict as CFDictionary)
            else { return nil }

            let appKitRect = convertQuartzRectToAppKit(quartzBounds, screens: screens)
                .insetBy(dx: padding, dy: padding)
            guard appKitRect.width >= 40, appKitRect.height >= 40 else { return nil }
            return appKitRect
        }
    }

    private static func convertQuartzRectToAppKit(_ rect: CGRect, screens: [NSScreen]) -> CGRect {
        guard let screen = screens.first(where: { quartzRectIntersects($0, rect) }) ?? NSScreen.main else {
            return rect
        }

        // CGWindow bounds are reported in a top-left display coordinate space;
        // NSWindow frames use AppKit's bottom-left coordinate space.
        let y = screen.frame.maxY - (rect.origin.y - screen.frame.minY) - rect.height
        return CGRect(x: rect.origin.x,
                      y: y,
                      width: rect.width,
                      height: rect.height)
    }

    private static func quartzRectIntersects(_ screen: NSScreen, _ rect: CGRect) -> Bool {
        let converted = CGRect(x: screen.frame.minX,
                               y: 0,
                               width: screen.frame.width,
                               height: screen.frame.height)
        return converted.intersects(rect)
    }
}
