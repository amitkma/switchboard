import SwiftUI

struct SettingsView: View {
    @Bindable var store: RouterStore
    let defaultBrowser: DefaultBrowserStatus
    @State private var browsers = Browser.installed()
    @State private var draggedRule: UUID?
    @State private var dragOffset: CGFloat = 0
    @State private var dragBaseline: CGFloat = 0

    private static let rowHeight: CGFloat = 36

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !defaultBrowser.isDefault {
                DefaultBrowserBanner(status: defaultBrowser)
            }

            BrowserPicker(title: "Fallback browser:", selection: $store.fallback, browsers: browsers)

            // Not a List: tables wait about a second before a click starts editing a text field.
            ScrollView {
                VStack(spacing: 0) {
                    ForEach($store.rules) { $rule in
                        // Capture the ID now. Reading `rule` inside removeAll would read
                        // store.rules during its own mutation, which crashes the app.
                        RuleRow(
                            rule: $rule,
                            browsers: browsers,
                            onDrag: { [id = rule.id] in drag(id, by: $0) },
                            onDragEnd: endDrag,
                            onMove: { [id = rule.id] in move(id, by: $0) },
                            onDelete: { [id = rule.id] in store.rules.removeAll { $0.id == id } }
                        )
                        .frame(height: Self.rowHeight)
                        .offset(y: draggedRule == rule.id ? dragOffset : 0)
                        .zIndex(draggedRule == rule.id ? 1 : 0)
                    }
                }
                .padding(8)
            }
            .background(.background)
            .border(.separator)

            HStack(alignment: .top) {
                Button("Add Rule", systemImage: "plus") {
                    store.rules.append(Rule(domain: "", browser: store.fallback))
                }
                Text("Rules run from top to bottom and the first match wins. Drag the handle to reorder them. A domain also matches its subdomains.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding()
        .frame(minWidth: 440, minHeight: 300)
        // Picks up browsers installed or removed since the window was last used.
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            browsers = Browser.installed()
        }
    }

    /// Swaps the dragged row with its neighbor each time it crosses half a row.
    private func drag(_ id: UUID, by translation: CGFloat) {
        draggedRule = id
        dragOffset = translation - dragBaseline
        let direction = dragOffset > 0 ? 1 : -1
        guard abs(dragOffset) > Self.rowHeight / 2, move(id, by: direction) else { return }
        dragBaseline += CGFloat(direction) * Self.rowHeight
        dragOffset = translation - dragBaseline
    }

    private func endDrag() {
        draggedRule = nil
        dragOffset = 0
        dragBaseline = 0
    }

    @discardableResult
    private func move(_ id: UUID, by steps: Int) -> Bool {
        guard let index = store.rules.firstIndex(where: { $0.id == id }),
              store.rules.indices.contains(index + steps) else { return false }
        store.rules.swapAt(index, index + steps)
        return true
    }
}

/// Explains why links aren't arriving and offers the fix. Hidden once the app is the default.
private struct DefaultBrowserBanner: View {
    let status: DefaultBrowserStatus

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Switchboard isn’t your default browser, so it can’t route your links yet.")
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
                Button("Set as Default") {
                    Task { await status.requestDefault() }
                }
                .buttonStyle(.borderedProminent)
            }
            if status.requestDidNotChange {
                HStack {
                    Text("Your default browser didn’t change. You can also choose Switchboard in System Settings.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer()
                    Button("Open System Settings", action: status.openSystemSettings)
                }
            }
        }
        .padding(10)
        .background(.quaternary, in: .rect(cornerRadius: 8))
    }
}

private struct RuleRow: View {
    @Binding var rule: Rule
    let browsers: [Browser]
    let onDrag: (CGFloat) -> Void
    let onDragEnd: () -> Void
    let onMove: (Int) -> Void
    let onDelete: () -> Void

    private var isInvalid: Bool {
        !rule.domain.isEmpty && DomainMatcher.normalizedDomain(rule.domain) == nil
    }

    var body: some View {
        HStack {
            Image(systemName: "line.3.horizontal")
                .foregroundStyle(.secondary)
                .frame(width: 22, height: 28)
                .contentShape(.rect)
                .pointerStyle(.grabIdle)
                .gesture(
                    DragGesture(coordinateSpace: .global)
                        .onChanged { onDrag($0.translation.height) }
                        .onEnded { _ in onDragEnd() }
                )
                .accessibilityLabel("Reorder rule")
                .accessibilityAction(named: "Move Up") { onMove(-1) }
                .accessibilityAction(named: "Move Down") { onMove(1) }
            TextField("Domain", text: $rule.domain, prompt: Text("example.com"))
                .labelsHidden()
                .textFieldStyle(.roundedBorder)
            if isInvalid {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.yellow)
                    .help("This isn’t a valid domain, so the rule is skipped.")
                    .accessibilityLabel("Invalid domain")
            }
            BrowserPicker(title: "Browser", selection: $rule.browser, browsers: browsers)
                .labelsHidden()
            Button("Delete Rule", systemImage: "trash", action: onDelete)
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
        }
    }
}

/// Lists installed browsers, plus the current choice if it has since been uninstalled.
private struct BrowserPicker: View {
    let title: String
    @Binding var selection: Browser
    let browsers: [Browser]

    var body: some View {
        Picker(title, selection: $selection) {
            ForEach(browsers) { Text($0.name).tag($0) }
            if !browsers.contains(selection) {
                Text("\(selection.name) (not installed)").tag(selection)
            }
        }
        .fixedSize()
    }
}
