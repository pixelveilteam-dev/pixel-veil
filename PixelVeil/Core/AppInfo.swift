//
//  AppInfo.swift
//  Pixel Veil
//
//  Central home for runtime-derived app metadata (version, build, marketing
//  URL). Reads `CFBundleShortVersionString` from Info.plist so the UI never
//  drifts from the build number.
//

import Foundation

enum AppInfo {
    /// Semver marketing version (CFBundleShortVersionString). Falls back to
    /// "0.0.0" so a broken bundle doesn't crash the UI.
    static var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
            ?? "0.0.0"
    }

    /// The GitHub releases API endpoint to poll for updates.
    static let releasesAPI = URL(
        string: "https://api.github.com/repos/pixelveilteam-dev/pixel-veil/releases/latest"
    )!

    /// User-facing URL for the release tag. Populated by UpdateChecker once
    /// the API has responded.
    static let releasesHTML = URL(
        string: "https://github.com/pixelveilteam-dev/pixel-veil/releases"
    )!
}
