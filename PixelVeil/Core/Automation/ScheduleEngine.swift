//
//  ScheduleEngine.swift
//  Pixel Veil
//
//  Ticks once a minute and asks the overlay controller to apply a schedule-based
//  override. The engine is intentionally coarse — minute resolution is enough
//  for "weekdays 9 to 5" style rules and keeps power usage near zero.
//

import Combine
import Foundation

final class ScheduleEngine: ObservableObject {
    private weak var settings: SettingsStore?
    private weak var overlay: OverlayController?
    private var timer: Timer?
    private var bag = Set<AnyCancellable>()

    func bind(settings: SettingsStore, overlay: OverlayController) {
        self.settings = settings
        self.overlay = overlay

        // Fire once on bind and every minute thereafter.
        tick()
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.tick()
        }
        timer?.tolerance = 10

        // Hop to the next main-queue tick so `tick()`'s `settings.schedule`
        // read returns the newly committed value. Without this, the first
        // toggle of the schedule switch lags by one click.
        settings.$schedule
            .sink { [weak self] _ in
                DispatchQueue.main.async { self?.tick() }
            }
            .store(in: &bag)
    }

    deinit { timer?.invalidate() }

    private func tick() {
        guard let settings = settings, let overlay = overlay else { return }
        let rule = settings.schedule
        guard rule.isEnabled else {
            // If schedule is disabled, leave forcedOn/Off alone — app rules
            // may still be driving state.
            return
        }

        let now = Date()
        let cal = Calendar.current
        let weekday = cal.component(.weekday, from: now)
        guard rule.weekdays.contains(weekday) else {
            overlay.forcedOn = false
            return
        }

        let minutesNow = cal.component(.hour, from: now) * 60 + cal.component(.minute, from: now)
        let start = rule.startHour * 60 + rule.startMinute
        let end   = rule.endHour   * 60 + rule.endMinute

        let inWindow: Bool
        if start <= end {
            inWindow = minutesNow >= start && minutesNow < end
        } else {
            // Overnight window (e.g. 22:00 -> 06:00)
            inWindow = minutesNow >= start || minutesNow < end
        }

        // Schedule only *requests ON*; it never forces OFF, so an explicit
        // deactivate app rule still wins.
        overlay.forcedOn = inWindow
    }
}
