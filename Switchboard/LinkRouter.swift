import AppKit
import Observation
import os
import UniformTypeIdentifiers

extension Browser {
    /// Every installed browser except this app, sorted by name. Apps that only claim web
    /// links, such as terminals and download managers, are left out by also requiring HTML.
    static func installed() -> [Browser] {
        let workspace = NSWorkspace.shared
        let htmlApps = Set(workspace.urlsForApplications(toOpen: UTType.html))
        var seen = Set<String>()
        return workspace.urlsForApplications(toOpen: URL(string: "https://example.com")!)
            .filter(htmlApps.contains)
            .compactMap { app -> Browser? in
                guard let id = Bundle(url: app)?.bundleIdentifier,
                      id != Bundle.main.bundleIdentifier,
                      seen.insert(id).inserted else { return nil }
                return Browser(bundleID: id, name: app.deletingPathExtension().lastPathComponent)
            }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    var appURL: URL? {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
    }
}

/// Holds the rules and fallback browser, saved to UserDefaults on every change.
@Observable final class RouterStore {
    var rules: [Rule] { didSet { save() } }
    var fallback: Browser { didSet { save() } }

    private struct Saved: Codable {
        var rules: [Rule]
        var fallback: Browser
    }

    private static let key = "routerSettings"

    init() {
        // The examples appear only on first run, so deleting them is permanent.
        let saved = UserDefaults.standard.data(forKey: Self.key)
            .flatMap { try? JSONDecoder().decode(Saved.self, from: $0) }
        rules = saved?.rules ?? [
            Rule(domain: "github.com", browser: .chrome),
            Rule(domain: "google.com", browser: .chrome),
            Rule(domain: "mozilla.org", browser: .firefox),
        ]
        fallback = saved?.fallback ?? .chrome
    }

    private func save() {
        let data = try? JSONEncoder().encode(Saved(rules: rules, fallback: fallback))
        UserDefaults.standard.set(data, forKey: Self.key)
    }
}

/// Chooses a browser for each link and opens the link in it.
final class LinkRouter {
    private let store: RouterStore
    private let log = Logger(subsystem: "io.github.amitkma.switchboard", category: "routing")

    init(store: RouterStore) {
        self.store = store
    }

    func open(_ url: URL) {
        // Local .html files can arrive here because of the HTML document type in Info.plist.
        // They have no domain to match, so DomainMatcher sends them to the fallback browser.
        guard ["http", "https", "file"].contains(url.scheme?.lowercased()) else { return }
        open(url, in: DomainMatcher.browser(for: url, rules: store.rules, fallback: store.fallback))
    }

    private func open(_ url: URL, in browser: Browser) {
        guard let app = browser.appURL else {
            offerOtherBrowser(for: url, failed: browser, message: "\(browser.name) isn’t installed.")
            return
        }
        Task {
            do {
                // Opening by app bundle ignores the default browser, so links can't loop back here.
                _ = try await NSWorkspace.shared.open([url], withApplicationAt: app, configuration: .init())
                log.notice("Opened link in \(browser.name, privacy: .public)")
            } catch {
                offerOtherBrowser(for: url, failed: browser, message: "\(browser.name) couldn’t open the link.")
            }
        }
    }

    private func offerOtherBrowser(for url: URL, failed browser: Browser, message: String) {
        log.error("\(message, privacy: .public)")
        let others = Browser.installed().filter { $0 != browser }

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = message
        alert.informativeText = others.isEmpty
            ? "No other browser is installed, so this link can’t be opened.\n\n\(url.absoluteString)"
            : "Choose another browser for this link:\n\n\(url.absoluteString)"

        let picker = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 240, height: 26))
        if !others.isEmpty {
            others.forEach { picker.addItem(withTitle: $0.name) }
            picker.selectItem(at: others.firstIndex(of: store.fallback) ?? 0)
            alert.accessoryView = picker
            alert.addButton(withTitle: "Open")
            alert.addButton(withTitle: "Cancel")
        }
        // A menu bar app must activate itself or the alert can appear behind other windows.
        NSApp.activate()
        if alert.runModal() == .alertFirstButtonReturn, !others.isEmpty {
            open(url, in: others[picker.indexOfSelectedItem])
        }
    }
}
