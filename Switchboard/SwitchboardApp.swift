import SwiftUI

@main struct SwitchboardApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("Switchboard", systemImage: "arrow.triangle.branch") {
            MenuContent()
        }

        // Without the last three modifiers, SwiftUI opens this window at launch or
        // whenever a link arrives. It should only open from the menu.
        Window("Switchboard Settings", id: "settings") {
            SettingsView(store: appDelegate.store)
        }
        .defaultSize(width: 480, height: 400)
        .defaultLaunchBehavior(.suppressed)
        .restorationBehavior(.disabled)
        .handlesExternalEvents(matching: [])
    }
}

/// macOS delivers links here both when it launches the app to open one and
/// when the app is already running, so no other URL handling is needed.
final class AppDelegate: NSObject, NSApplicationDelegate {
    let store = RouterStore()
    private lazy var router = LinkRouter(store: store)

    func application(_ application: NSApplication, open urls: [URL]) {
        urls.forEach(router.open)
    }
}

private struct MenuContent: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Settings…") {
            // A menu bar app isn't active by default, so without this the window opens behind others.
            NSApp.activate()
            openWindow(id: "settings")
        }
        .keyboardShortcut(",")
        Divider()
        Button("Quit Switchboard") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}
