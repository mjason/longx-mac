import SwiftUI

struct ContentView: View {
    @ObservedObject var store: ServerStore
    @ObservedObject var pool: SessionPool
    @Binding var editing: Server?
    @Binding var showingEditor: Bool
    @State private var deleting: Server?
    @State private var showingServers = false

    private func closeServers() {
        withAnimation(.easeInOut(duration: 0.18)) { showingServers = false }
        if let server = store.selected {
            let webView = pool.session(for: server).webView
            webView.window?.makeFirstResponder(webView)
        }
    }

    var body: some View {
        Group {
            if let server = store.selected {
                SessionView(session: pool.session(for: server))
            } else {
                ContentUnavailableView {
                    Label(String(localized: "Add Your LongX Server"), systemImage: "server.rack")
                } description: {
                    Text(String(localized: "Each server keeps its own sign-in state and web session."))
                } actions: {
                    Button(String(localized: "Add Server")) { editing = nil; showingEditor = true }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Overlay never participates in the web surface's layout.
        .overlay(alignment: .topLeading) {
            if showingServers {
                ZStack(alignment: .topLeading) {
                    Color.black.opacity(0.001)
                        .contentShape(Rectangle())
                        .onTapGesture { closeServers() }
                        .accessibilityLabel(String(localized: "Close Server Panel"))
                    serverPanel
                        .padding(12)
                        .transition(.move(edge: .leading).combined(with: .opacity))
                }
            }
        }
        .onChange(of: store.selectedID) { _, _ in closeServers() }
        .onChange(of: showingEditor) { _, value in if value { closeServers() } }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) { showingServers.toggle() }
                } label: {
                    Label(store.selected?.name ?? String(localized: "Servers"), systemImage: "sidebar.left")
                }.help(String(localized: "Switch and Manage Servers"))
            }
        }
        .confirmationDialog(String(format: String(localized: "Remove %@?"), deleting?.name ?? String(localized: "Server")), isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }), titleVisibility: .visible) {
            Button(String(localized: "Remove Server and Local Sign-in Data"), role: .destructive) {
                if let server = deleting { store.remove(server.id); pool.remove(server.id) }
                deleting = nil
            }
        } message: { Text(String(localized: "Data on the server will not be affected.")) }
    }

    private var serverPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(String(localized: "Servers")).font(.headline)
                Spacer()
                Button { closeServers() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 24, height: 24)
                        .background(Color.primary.opacity(0.05), in: Circle())
                }
                    .buttonStyle(.plain).help(String(localized: "Close Server Panel"))
                    .keyboardShortcut(.cancelAction)
            }
            ScrollView {
                VStack(spacing: 6) {
                    ForEach(Array(store.servers.enumerated()), id: \.element.id) { index, server in
                        HStack(spacing: 6) {
                            Button {
                                store.selectedID = server.id
                                closeServers()
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: "server.rack")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(store.selectedID == server.id ? Color.accentColor : Color.secondary)
                                        .frame(width: 30, height: 30)
                                        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(server.name).font(.system(size: 13, weight: .medium)).lineLimit(1)
                                        Text(server.address).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
                                    }
                                    Spacer(minLength: 0)
                                    if store.selectedID == server.id {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 11, weight: .semibold)).foregroundStyle(Color.accentColor)
                                    }
                                }.contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .help(index < 9 ? "⌘⌥\(index + 1)" : server.address)
                            .contextMenu {
                                Button(String(localized: "Edit Server…")) { editing = server; showingEditor = true }
                                Button(String(localized: "Remove Server…"), role: .destructive) { deleting = server }
                            }
                            Menu {
                                Button { editing = server; showingEditor = true } label: {
                                    Label(String(localized: "Edit Name and Address…"), systemImage: "pencil")
                                }
                                Divider()
                                Button(role: .destructive) { deleting = server } label: {
                                    Label(String(localized: "Remove Server…"), systemImage: "trash")
                                }
                            } label: {
                                Image(systemName: "ellipsis")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 24, height: 28)
                                    .contentShape(Rectangle())
                            }
                            .menuStyle(.borderlessButton)
                            .menuIndicator(.hidden)
                            .fixedSize()
                            .help(String(localized: "Edit or Remove Server"))
                            .accessibilityLabel(String(format: String(localized: "Manage Server %@"), server.name))
                        }
                        .padding(10)
                        .background(store.selectedID == server.id ? Color.accentColor.opacity(0.10) : Color.primary.opacity(0.025),
                                    in: RoundedRectangle(cornerRadius: 12))
                    }
                }
            }.frame(height: min(CGFloat(max(store.servers.count, 1)) * 62, 320))
            Divider()
            Button { editing = nil; showingEditor = true } label: {
                Label(String(localized: "Add Server"), systemImage: "plus")
                    .font(.system(size: 12, weight: .medium))
                    .frame(maxWidth: .infinity)
            }.longXGlassButton()
        }
        .padding(16)
        .frame(width: 300)
        .longXGlassPanel()
        .shadow(color: .black.opacity(0.12), radius: 16, y: 6)
    }

}

struct SessionView: View {
    @ObservedObject var session: WebSession
    var body: some View {
        VStack(spacing: 0) {
            if let error = session.error {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                    Text(error).font(.callout).textSelection(.enabled)
                    Spacer()
                    Button(String(localized: "Retry")) { session.reload() }
                }.padding(12).longXGlassPanel().padding(8)
            }
            ZStack(alignment: .top) {
                WebSurface(webView: session.webView)
                if session.loading { ProgressView(value: session.progress).progressViewStyle(.linear) }
            }
        }
        .navigationTitle(session.server.name)
        .preferredColorScheme(session.preferredScheme)
        .toolbarBackground(session.chromeColor, for: .windowToolbar)
        .toolbarBackground(.visible, for: .windowToolbar)
        .toolbar {
            ToolbarItemGroup {
                Button { session.webView.goBack() } label: { Image(systemName: "chevron.left") }.help(String(localized: "Back"))
                Button { session.webView.goForward() } label: { Image(systemName: "chevron.right") }.help(String(localized: "Forward"))
                Button { session.reload() } label: { Image(systemName: "arrow.clockwise") }.help(String(localized: "Reload (⌘R)"))
            }
        }
    }
}

struct ServerEditor: View {
    let server: Server?
    let save: (Server) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var address: String

    init(server: Server?, save: @escaping (Server) -> Void) {
        self.server = server; self.save = save
        _name = State(initialValue: server?.name ?? "")
        _address = State(initialValue: server?.address ?? "")
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(server == nil ? String(localized: "Add Server") : String(localized: "Edit Server")).font(.title2.bold())
            Form {
                TextField(String(localized: "Name"), text: $name, prompt: Text(String(localized: "For example: Work Server")))
                TextField(String(localized: "Address"), text: $address, prompt: Text("https://longx.example.com:7443"))
            }.textFieldStyle(.roundedBorder)
            Text(String(localized: "Supports HTTPS and local network HTTP. HTTPS is used if no scheme is entered. Changing the address reloads the server."))
                .font(.caption).foregroundStyle(.secondary)
            if !address.isEmpty && Server.validatedURL(address) == nil {
                Text(String(localized: "Enter a valid address. Sign in on the webpage.")).foregroundStyle(.red).font(.caption)
            }
            HStack {
                Spacer()
                Button(String(localized: "Cancel")) { dismiss() }.longXGlassButton().keyboardShortcut(.cancelAction)
                Button(String(localized: "Save")) {
                    save(Server(id: server?.id ?? UUID(), name: name, address: address)); dismiss()
                }.longXGlassButton(prominent: true).keyboardShortcut(.defaultAction).disabled(Server.validatedURL(address) == nil)
            }
        }.padding(24).frame(width: 460)
    }
}
