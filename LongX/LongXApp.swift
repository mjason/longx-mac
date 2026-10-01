import SwiftUI

@main
struct LongXApp: App {
    @StateObject private var store = ServerStore()
    @StateObject private var pool = SessionPool()
    @StateObject private var updater = UpdateChecker()
    @State private var editing: Server?
    @State private var showingEditor = false

    var body: some Scene {
        Window("LongX", id: "main") {
            ContentView(store: store, pool: pool, editing: $editing, showingEditor: $showingEditor)
                .frame(minWidth: 900, minHeight: 600)
                .sheet(isPresented: $showingEditor) {
                    ServerEditorSheet(editing: $editing, store: store)
                }
        }
        .defaultSize(width: 1360, height: 900)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(after: .appInfo) {
                Button(String(localized: "Check for Updates…")) { updater.check() }
                    .disabled(!updater.canCheckForUpdates)
                Toggle(String(localized: "Automatically Download and Install Updates"), isOn: Binding(
                    get: { updater.automaticallyDownloadsUpdates },
                    set: { updater.setAutomaticUpdates($0) }
                ))
            }
            CommandGroup(replacing: .appSettings) {
                Button(String(localized: "Manage Servers…")) { editing = store.selected; showingEditor = true }
                    .keyboardShortcut(",", modifiers: [.command, .option])
            }
            CommandMenu(String(localized: "Servers")) {
                Button(String(localized: "Add Server…")) { editing = nil; showingEditor = true }
                    .keyboardShortcut("n", modifiers: [.command, .option])
                Divider()
                ForEach(Array(store.servers.prefix(9).enumerated()), id: \.element.id) { index, server in
                    Button(server.name) { store.select(index) }
                        .keyboardShortcut(KeyEquivalent(Character(String(index + 1))), modifiers: [.command, .option])
                }
                Divider()
                Button(String(localized: "Reload Server")) { if let server = store.selected { pool.session(for: server).reload() } }
                    .keyboardShortcut("r", modifiers: .command)
            }
            CommandGroup(replacing: .windowSize) {
                Button(String(localized: "Close Window")) { NSApp.keyWindow?.close() }
                    .keyboardShortcut("w", modifiers: [.command, .shift])
            }
        }
    }
}

private struct ServerEditorSheet: View {
    @Binding var editing: Server?
    @ObservedObject var store: ServerStore
    var body: some View {
        ServerEditor(server: editing) { store.save($0) }
    }
}
