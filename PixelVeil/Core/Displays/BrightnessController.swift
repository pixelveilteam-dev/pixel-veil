//
//  BrightnessController.swift
//  Pixel Veil
//
//  Forces display brightness down while Privacy Mode is active.
//
//  macOS has no public brightness API for the built-in or external panels.
//  The only reliable cross-silicon path is the private DisplayServices
//  framework (the same symbols the `brightness` CLI tool uses). We load it
//  with dlopen/dlsym so the app still builds cleanly against the public SDK.
//
//  Behaviour
//  ---------
//  * On activation, stores each display's current brightness and ramps it
//    down to `target` (default 20 %) in ~20 steps over 0.3 s.
//  * On deactivation, ramps back up to the stored value.
//  * On app quit, restores synchronously before terminating.
//  * If DisplayServices symbols can't be resolved (rare — means the private
//    framework moved), the service no-ops silently rather than crashing.
//
//  Dimming the panel is more than a comfort feature here: it amplifies the
//  contrast-reduction veil, because the veil alpha multiplies against a
//  smaller native luminance, pushing side-viewer legibility further below
//  their reading threshold.
//

import AppKit
import Darwin

final class BrightnessController {
    private typealias GetFn = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
    private typealias SetFn = @convention(c) (CGDirectDisplayID, Float) -> Int32
    // Auto-brightness symbols. Not all OS versions expose the same ones — some
    // builds ship `DisplayServicesSetAutoBrightnessIsEnabled`, others
    // `CBSDisplayServicesSetAutoBrightnessIsEnabled`. We probe both.
    private typealias GetAutoFn = @convention(c) (CGDirectDisplayID) -> Bool
    private typealias SetAutoFn = @convention(c) (CGDirectDisplayID, Bool) -> Int32

    private let getFn: GetFn?
    private let setFn: SetFn?
    private let getAutoFn: GetAutoFn?
    private let setAutoFn: SetAutoFn?
    private var saved: [CGDirectDisplayID: Float] = [:]
    private var savedAuto: [CGDirectDisplayID: Bool] = [:]
    private var rampTimer: Timer?
    // Periodic re-apply to fight anything that tries to move brightness back
    // (auto-brightness, True Tone, Low Power Mode adjustments).
    private var holdTimer: Timer?
    private var currentTarget: Float = 0.2
    private(set) var isDimming: Bool = false

    init() {
        // DisplayServices lives in /System/Library/PrivateFrameworks. It is
        // present on every macOS 10.13+ install; the symbols we need have
        // been stable since Mojave.
        let handle = dlopen(
            "/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices",
            RTLD_LAZY
        )
        if let handle = handle,
           let getSym = dlsym(handle, "DisplayServicesGetBrightness"),
           let setSym = dlsym(handle, "DisplayServicesSetBrightness") {
            self.getFn = unsafeBitCast(getSym, to: GetFn.self)
            self.setFn = unsafeBitCast(setSym, to: SetFn.self)
        } else {
            self.getFn = nil
            self.setFn = nil
        }
        // Best-effort auto-brightness toggles. If the symbols aren't there we
        // just fall back to the hold timer.
        let getAutoSym = handle.flatMap { dlsym($0, "DisplayServicesGetAutoBrightnessIsEnabled") }
                         ?? handle.flatMap { dlsym($0, "DisplayServicesIsAutoBrightnessEnabled") }
        let setAutoSym = handle.flatMap { dlsym($0, "DisplayServicesSetAutoBrightnessIsEnabled") }
                         ?? handle.flatMap { dlsym($0, "DisplayServicesSetAutoBrightness") }
        self.getAutoFn = getAutoSym.map { unsafeBitCast($0, to: GetAutoFn.self) }
        self.setAutoFn = setAutoSym.map { unsafeBitCast($0, to: SetAutoFn.self) }
    }

    // MARK: Public API

    func applyDim(target: Float) {
        guard setFn != nil, getFn != nil else { return }
        stopRamp()
        currentTarget = target

        // Snapshot current brightness AND auto-brightness state once per dim
        // session. Re-entry while already dimming just updates the target —
        // we must not overwrite saved values with a dimmed reading.
        if !isDimming {
            for id in Self.onlineDisplays() {
                if let current = readBrightness(id) {
                    saved[id] = current
                }
                if let getAutoFn = getAutoFn {
                    savedAuto[id] = getAutoFn(id)
                }
                // Disable auto-brightness so the ambient-light sensor won't
                // fight our target. We restore the original state on release.
                _ = setAutoFn?(id, false)
            }
        }
        isDimming = true
        ramp(to: target, restoring: false)
        startHoldTimer()
    }

    func restore() {
        stopRamp()
        stopHoldTimer()
        // Re-enable auto-brightness for every display we touched, using the
        // original per-display state. Do this before the ramp so the sensor
        // has time to stabilise by the time we hand back.
        for (id, wasEnabled) in savedAuto {
            _ = setAutoFn?(id, wasEnabled)
        }
        savedAuto.removeAll()

        guard !saved.isEmpty else {
            isDimming = false
            return
        }
        ramp(to: nil, restoring: true)
    }

    /// Synchronous restore for app termination. No animation.
    func restoreImmediately() {
        stopRamp()
        stopHoldTimer()
        for (id, wasEnabled) in savedAuto {
            _ = setAutoFn?(id, wasEnabled)
        }
        savedAuto.removeAll()
        for (id, value) in saved {
            _ = setFn?(id, value)
        }
        saved.removeAll()
        isDimming = false
    }

    // MARK: Hold timer — keeps brightness pinned at target

    private func startHoldTimer() {
        stopHoldTimer()
        // Re-apply the target every 2s. True Tone, auto-brightness updates we
        // failed to disable, or a user tap on F1/F2 can all move the
        // brightness; this pulls it back gently.
        holdTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            guard let self = self, self.isDimming else { return }
            // Skip while a user-initiated ramp is in progress.
            if self.rampTimer != nil { return }
            for id in self.saved.keys {
                let now = self.readBrightness(id) ?? 0
                // Only nudge if drift > 3 % — avoids constant micro-writes.
                if abs(now - self.currentTarget) > 0.03 {
                    _ = self.setFn?(id, self.currentTarget)
                }
            }
        }
        holdTimer?.tolerance = 0.5
    }

    private func stopHoldTimer() {
        holdTimer?.invalidate()
        holdTimer = nil
    }

    // MARK: Implementation

    private func readBrightness(_ id: CGDirectDisplayID) -> Float? {
        guard let getFn = getFn else { return nil }
        var value: Float = 0
        let status = getFn(id, &value)
        return status == 0 ? value : nil
    }

    private static func onlineDisplays() -> [CGDirectDisplayID] {
        var count: UInt32 = 0
        CGGetOnlineDisplayList(16, nil, &count)
        guard count > 0 else { return [] }
        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        CGGetOnlineDisplayList(count, &ids, &count)
        return Array(ids.prefix(Int(count)))
    }

    private func ramp(to target: Float?, restoring: Bool) {
        let steps = 18
        let duration = 0.30
        var step = 0

        // Capture starts per display at ramp time — current brightness may
        // not equal `saved` if the user moved the slider mid-session.
        var starts: [CGDirectDisplayID: Float] = [:]
        for id in saved.keys {
            starts[id] = readBrightness(id) ?? saved[id] ?? 0.5
        }

        rampTimer = Timer.scheduledTimer(withTimeInterval: duration / Double(steps), repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            step += 1
            let fraction = Float(step) / Float(steps)
            for (id, start) in starts {
                let end: Float
                if restoring {
                    end = self.saved[id] ?? start
                } else if let target = target {
                    end = target
                } else {
                    end = start
                }
                let v = start + (end - start) * fraction
                _ = self.setFn?(id, max(0.0, min(1.0, v)))
            }
            if step >= steps {
                t.invalidate()
                self.rampTimer = nil
                if restoring {
                    self.saved.removeAll()
                    self.isDimming = false
                }
            }
        }
    }

    private func stopRamp() {
        rampTimer?.invalidate()
        rampTimer = nil
    }
}
