import AppKit
import Observation
import os

/// Tracks whether this app is the default browser and asks macOS to make it so.
/// macOS always confirms the change with the user, so an app can't take the role silently.
@Observable final class DefaultBrowserStatus {
    private(set) var isDefault = false
    /// The last request ended without a change, either because the user kept their
    /// current browser or because macOS refused. The app treats both the same way.
    private(set) var requestDidNotChange = false
    /// True only on the first launch that finds another default browser, so the app asks once.
    let shouldPromptAtLaunch: Bool

    private static let promptedKey = "defaultBrowserPromptShown"
    private static let schemes = ["http", "https"]
    private let log = Logger(subsystem: "io.github.amitkma.switchboard", category: "defaultBrowser")

    init() {
        let isDefaultAtLaunch = Self.schemes.allSatisfy { Self.isHandler(of: $0) }
        let defaults = UserDefaults.standard
        shouldPromptAtLaunch = !isDefaultAtLaunch && !defaults.bool(forKey: Self.promptedKey)
        defaults.set(true, forKey: Self.promptedKey)
        isDefault = isDefaultAtLaunch

        // macOS has no public notification for a default browser change. The user makes
        // that change in another app or in a system prompt, so check on every app switch.
        Task { [weak self] in
            let center = NSWorkspace.shared.notificationCenter
            for await _ in center.notifications(named: NSWorkspace.didActivateApplicationNotification) {
                self?.refresh()
            }
        }
    }

    func refresh() {
        let current = Self.schemes.allSatisfy { Self.isHandler(of: $0) }
        if current != isDefault { isDefault = current }
        if current { requestDidNotChange = false }
    }

    func requestDefault() async {
        requestDidNotChange = false
        // A menu bar app must activate itself or the system prompt can appear behind other windows.
        NSApp.activate()
        do {
            // Accepting the prompt for one scheme can cover the other, so check before each request.
            for scheme in Self.schemes where !Self.isHandler(of: scheme) {
                try await NSWorkspace.shared.setDefaultApplication(at: Bundle.main.bundleURL, toOpenURLsWithScheme: scheme)
            }
        } catch {
            let error = error as NSError
            log.notice("Default browser unchanged: \(error.domain, privacy: .public) \(error.code)")
        }
        refresh()
        requestDidNotChange = !isDefault
        log.notice("Default browser request finished, isDefault: \(self.isDefault)")
    }

    func openSystemSettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Desktop-Settings.extension")!)
    }

    private static func isHandler(of scheme: String) -> Bool {
        guard let url = URL(string: "\(scheme)://example.com"),
              let app = NSWorkspace.shared.urlForApplication(toOpen: url) else { return false }
        // Compare IDs, not paths, because another copy of this app may be the registered one.
        return Bundle(url: app)?.bundleIdentifier == Bundle.main.bundleIdentifier
    }
}
