//
//  GammaAssistController.swift
//  Pixel Veil
//
//  Uses public CoreGraphics gamma tables as a subtle assist to the Metal
//  privacy mask. It compresses output luminance a little, never to black, and
//  restores the original ColorSync tables when Privacy Mode turns off.
//

import AppKit
import CoreGraphics

final class GammaAssistController {
    private struct SavedGamma {
        let red: [CGGammaValue]
        let green: [CGGammaValue]
        let blue: [CGGammaValue]
    }

    private var saved: [CGDirectDisplayID: SavedGamma] = [:]
    private(set) var isAssistActive = false

    func applyAssist(factor: Double, enabledDisplayIDs: Set<CGDirectDisplayID>? = nil) {
        let displays = Self.onlineDisplays().filter { id in
            enabledDisplayIDs?.contains(id) ?? true
        }
        guard !displays.isEmpty else { return }

        let clampedFactor = CGGammaValue(max(0.62, min(1.0, factor)))
        for id in displays {
            if saved[id] == nil, let current = readGamma(id) {
                saved[id] = current
            }
            if let original = saved[id] {
                setGamma(id, scaled(original, by: clampedFactor))
            }
        }
        isAssistActive = true
    }

    func restore() {
        guard isAssistActive || !saved.isEmpty else { return }
        for (id, table) in saved {
            setGamma(id, table)
        }
        saved.removeAll()
        CGDisplayRestoreColorSyncSettings()
        isAssistActive = false
    }

    private func readGamma(_ id: CGDirectDisplayID) -> SavedGamma? {
        let capacity = max(2, Int(CGDisplayGammaTableCapacity(id)))
        var red = [CGGammaValue](repeating: 0, count: capacity)
        var green = [CGGammaValue](repeating: 0, count: capacity)
        var blue = [CGGammaValue](repeating: 0, count: capacity)
        var sampleCount: UInt32 = 0

        let error = CGGetDisplayTransferByTable(
            id,
            UInt32(capacity),
            &red,
            &green,
            &blue,
            &sampleCount
        )
        guard error == .success, sampleCount > 0 else { return nil }

        let count = Int(sampleCount)
        return SavedGamma(
            red: Array(red.prefix(count)),
            green: Array(green.prefix(count)),
            blue: Array(blue.prefix(count))
        )
    }

    private func setGamma(_ id: CGDirectDisplayID, _ table: SavedGamma) {
        let count = min(table.red.count, table.green.count, table.blue.count)
        guard count > 0 else { return }
        CGSetDisplayTransferByTable(
            id,
            UInt32(count),
            table.red,
            table.green,
            table.blue
        )
    }

    private func scaled(_ table: SavedGamma, by factor: CGGammaValue) -> SavedGamma {
        SavedGamma(
            red: table.red.map { min(1.0, max(0.0, $0 * factor)) },
            green: table.green.map { min(1.0, max(0.0, $0 * factor)) },
            blue: table.blue.map { min(1.0, max(0.0, $0 * factor)) }
        )
    }

    private static func onlineDisplays() -> [CGDirectDisplayID] {
        var count: UInt32 = 0
        CGGetOnlineDisplayList(16, nil, &count)
        guard count > 0 else { return [] }
        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        CGGetOnlineDisplayList(count, &ids, &count)
        return Array(ids.prefix(Int(count)))
    }
}
