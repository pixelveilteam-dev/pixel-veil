//
//  LaunchAtLoginController.swift
//  Pixel Veil
//
//  Keeps the app registered with macOS Login Items using the modern
//  ServiceManagement API. Registration can require approval in System Settings;
//  in that case we leave the user's system-level choice alone.
//

import Foundation
import ServiceManagement
import os

final class LaunchAtLoginController {
    private let logger = Logger(subsystem: "com.pixelveil.app", category: "LaunchAtLogin")

    func sync(enabled: Bool) {
        let service = SMAppService.mainApp

        do {
            if enabled {
                guard service.status != .enabled,
                      service.status != .requiresApproval
                else { return }
                try service.register()
            } else {
                guard service.status == .enabled ||
                      service.status == .requiresApproval
                else { return }
                try service.unregister()
            }
        } catch {
            logger.error("Unable to sync launch-at-login: \(String(describing: error), privacy: .public)")
        }
    }
}
