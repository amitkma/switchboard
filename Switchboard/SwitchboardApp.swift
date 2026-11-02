import SwiftUI

@main struct SwitchboardApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("Switchboard", systemImage: "arrow.triangle.branch") {
            MenuContent(defaultBrowser: appDelegate.defaultBrowser)
        }

        // Without the last three modifiers, SwiftUI opens this window at launch or whenever
        // a link arrives. It should only open from the menu, or once on first launch so a
        // new user sees something and can make the app their default browser.
        Window(SettingsWindow.title, id: "settings") {
            SettingsView(store: appDelegate.store, defaultBrowser: appDelegate.defaultBrowser)
        }
        .defaultSize(width: 480, height: 400)
        .defaultLaunchBehavior(appDelegate.defaultBrowser.shouldPromptAtLaunch ? .presented : .suppressed)
        .restorationBehavior(.disabled)
        .handlesExternalEvents(matching: [])
    }
}

/// macOS delivers links here both when it launches the app to open one and
/// when the app is already running, so no other URL handling is needed.
final class AppDelegate: NSObject, NSApplicationDelegate {
    let store = RouterStore()
    let defaultBrowser = DefaultBrowserStatus()
    private lazy var router = LinkRouter(store: store)

    func application(_ application: NSApplication, open urls: [URL]) {
        urls.forEach(router.open)
    }
}

enum SettingsWindow {
    static let title = "Switchboard Settings"

    /// A menu bar app isn't active by default, and activate() is only a request that macOS can
    /// ignore. So also order the window front directly, and bring it to the current Space.
    static func bringToFront() {
        NSApp.activate()
        guard let window = NSApp.windows.first(where: { $0.title == title }) else { return }
        window.collectionBehavior.insert(.moveToActiveSpace)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }
}

private struct MenuContent: View {
    let defaultBrowser: DefaultBrowserStatus
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        if !defaultBrowser.isDefault {
            Button("Set as Default Browser…") {
                openSettings()
                Task { await defaultBrowser.requestDefault() }
            }
            Divider()
        }
        Button("Settings…", action: openSettings)
            .keyboardShortcut(",")
        Divider()
        Button("Quit Switchboard") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }

    private func openSettings() {
        openWindow(id: "settings")
        // openWindow does nothing to a window that's already open but hidden behind others.
        SettingsWindow.bringToFront()
    }
}
