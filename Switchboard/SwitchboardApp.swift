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
        Window("Switchboard Settings", id: "settings") {
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

    func applicationDidFinishLaunching(_ notification: Notification) {
        // A menu bar app isn't active by default, so without this the window opens behind others.
        if defaultBrowser.shouldPromptAtLaunch { NSApp.activate() }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        urls.forEach(router.open)
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
        // A menu bar app isn't active by default, so without this the window opens behind others.
        NSApp.activate()
        openWindow(id: "settings")
    }
}
