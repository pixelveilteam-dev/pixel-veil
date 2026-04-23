//
//  UpdateChecker.swift
//  Pixel Veil
//
//  Polls GitHub's public `releases/latest` endpoint for the pixel-veil repo
//  and compares the returned tag against the running bundle's version.
//  Exposes a simple @Published surface so the UI can show a banner when a
//  newer release ships.
//
//  Design choices
//  --------------
//  * Public endpoint, unauthenticated — GitHub allows 60 requests/hour per IP
//    for anonymous calls. We check once at launch and then every 6 hours, so
//    we burn at most ~5 requests per day per user.
//  * Never auto-downloads or auto-installs. The banner just links to the
//    Releases page. Users retain total control over when they upgrade.
//  * Comparison is a tuple-wise semver compare — "1.0.10" > "1.0.2" works.
//

import Foundation
import Combine

final class UpdateChecker: ObservableObject {
    /// The latest version tag seen from the API, normalised (no leading "v").
    @Published private(set) var latestVersion: String?
    /// True iff `latestVersion` is strictly newer than the running bundle.
    @Published private(set) var updateAvailable = false
    /// Direct URL for the user to open (the release's HTML page).
    @Published private(set) var releasePageURL: URL?

    /// User has dismissed the banner for this launch. Persists in-memory only;
    /// reappears the next launch if still out of date.
    @Published var dismissed = false

    private let currentVersion: String = AppInfo.version
    private var timer: Timer?

    func start() {
        check()
        // Re-check every 6 hours while the app is running.
        timer = Timer.scheduledTimer(withTimeInterval: 6 * 3600, repeats: true) { [weak self] _ in
            self?.check()
        }
        timer?.tolerance = 600
    }

    deinit { timer?.invalidate() }

    func check() {
        var request = URLRequest(url: AppInfo.releasesAPI)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        // GitHub's ETag-caching friendly — we're fine without a User-Agent,
        // but it doesn't hurt and silences some lint.
        request.setValue("PixelVeil/\(currentVersion)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 10

        URLSession.shared.dataTask(with: request) { [weak self] data, response, _ in
            guard
                let self = self,
                let data = data,
                (response as? HTTPURLResponse)?.statusCode == 200,
                let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            else { return }

            let rawTag = (json["tag_name"] as? String) ?? ""
            let normalised = rawTag.hasPrefix("v") ? String(rawTag.dropFirst()) : rawTag
            let html = (json["html_url"] as? String).flatMap(URL.init(string:))

            DispatchQueue.main.async {
                self.latestVersion = normalised.isEmpty ? nil : normalised
                self.releasePageURL = html ?? AppInfo.releasesHTML
                self.updateAvailable = Self.isNewer(normalised, than: self.currentVersion)
            }
        }.resume()
    }

    /// Semver compare by integer tuple. Handles "1.0.10" vs "1.0.2" correctly.
    static func isNewer(_ candidate: String, than current: String) -> Bool {
        func parts(_ s: String) -> [Int] {
            s.split(separator: ".").map { Int($0) ?? 0 }
        }
        let c = parts(candidate), cur = parts(current)
        for i in 0..<max(c.count, cur.count) {
            let a = i < c.count ? c[i] : 0
            let b = i < cur.count ? cur[i] : 0
            if a > b { return true }
            if a < b { return false }
        }
        return false
    }
}
