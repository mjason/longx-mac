import AppKit
import Combine

struct ReleaseVersion: Comparable {
    let parts: [Int]
    init?(_ value: String) {
        let value = value.hasPrefix("v") ? String(value.dropFirst()) : value
        let components = value.split(separator: ".", omittingEmptySubsequences: false)
        guard (1...3).contains(components.count), components.allSatisfy({ !$0.isEmpty && $0.allSatisfy { $0.isASCII && $0.isNumber } }) else { return nil }
        let numbers = components.compactMap { Int($0) }
        guard numbers.count == components.count else { return nil }
        parts = numbers + Array(repeating: 0, count: 3 - numbers.count)
    }
    static func < (lhs: Self, rhs: Self) -> Bool { lhs.parts.lexicographicallyPrecedes(rhs.parts) }
}

struct GitHubRelease: Decodable {
    let tag_name: String
    let html_url: URL
    let draft: Bool
    let prerelease: Bool
    let assets: [Asset]
    struct Asset: Decodable { let name: String }
    var downloadableURL: URL? {
        guard !draft, !prerelease, ReleaseVersion(tag_name) != nil,
              html_url.scheme == "https", html_url.host == "github.com", html_url.user == nil,
              html_url.password == nil, html_url.port == nil,
              html_url.path.hasPrefix("/mjason/longx-mac/releases/tag/"),
              assets.contains(where: { $0.name == "LongX-\(tag_name.hasPrefix("v") ? String(tag_name.dropFirst()) : tag_name)-macOS-universal.zip" }) else { return nil }
        return html_url
    }
}

@MainActor
final class UpdateChecker: ObservableObject {
    @Published private(set) var checking = false
    private let defaults = UserDefaults.standard
    private let currentVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.0"

    func checkAutomatically() async {
        // Daily checks stay quiet if the network is unavailable or no update exists.
        let last = defaults.object(forKey: "lastUpdateCheck") as? Date ?? .distantPast
        guard Date().timeIntervalSince(last) >= 24 * 60 * 60 else { return }
        await check(manual: false)
    }

    func check(manual: Bool = true) async {
        guard !checking else { return }
        checking = true
        defer { checking = false }
        do {
            var request = URLRequest(url: URL(string: "https://api.github.com/repos/mjason/longx-mac/releases/latest")!)
            request.timeoutInterval = 20
            request.cachePolicy = .reloadIgnoringLocalCacheData
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            request.setValue("LongX/\(currentVersion)", forHTTPHeaderField: "User-Agent")
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let response = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
            if response.statusCode == 404 {
                defaults.set(Date(), forKey: "lastUpdateCheck")
                if manual { show(String(localized: "No releases available yet.")) }
                return
            }
            guard response.statusCode == 200 else { throw URLError(.badServerResponse) }
            let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
            guard let latest = ReleaseVersion(release.tag_name), let current = ReleaseVersion(currentVersion) else { throw URLError(.cannotParseResponse) }
            defaults.set(Date(), forKey: "lastUpdateCheck")
            if latest > current {
                guard let url = release.downloadableURL else {
                    if manual { show(String(localized: "The latest release is not ready to download yet.")) }
                    return
                }
                let alert = NSAlert()
                alert.messageText = String(format: String(localized: "LongX %@ is available"), release.tag_name)
                alert.informativeText = String(format: String(localized: "You are using %@. Open GitHub to view release notes and download the update."), currentVersion)
                alert.addButton(withTitle: String(localized: "View Release"))
                alert.addButton(withTitle: String(localized: "Later"))
                if alert.runModal() == .alertFirstButtonReturn { NSWorkspace.shared.open(url) }
            } else if manual {
                show(String(format: String(localized: "LongX %@ is up to date."), currentVersion))
            }
        } catch {
            if manual { show(String(localized: "Unable to check for updates."), detail: error.localizedDescription) }
        }
    }

    private func show(_ message: String, detail: String = "") {
        let alert = NSAlert()
        alert.messageText = message
        alert.informativeText = detail
        alert.addButton(withTitle: String(localized: "OK"))
        alert.runModal()
    }
}
