import Foundation

struct Server: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var address: String

    static func validatedURL(_ input: String) -> URL? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let value = trimmed.contains("://") ? trimmed : "https://" + trimmed
        guard let url = URL(string: value), let scheme = url.scheme?.lowercased(),
              ["https", "http"].contains(scheme), let host = url.host, !host.isEmpty,
              url.user == nil, url.password == nil else { return nil }
        return url
    }

    var url: URL { Self.validatedURL(address)! }
}

@MainActor
final class ServerStore: ObservableObject {
    @Published private(set) var servers: [Server]
    @Published var selectedID: UUID? { didSet { persist() } }
    @Published var persistenceError: String?
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: "servers"), let saved = try? JSONDecoder().decode([Server].self, from: data) {
            servers = saved.filter { Server.validatedURL($0.address) != nil }
        } else {
            servers = [Server(name: "LongX", address: "https://longx.diz.plus:7443")]
        }
        let restored = defaults.string(forKey: "selectedServer").flatMap(UUID.init(uuidString:))
        selectedID = servers.first(where: { $0.id == restored })?.id ?? servers.first?.id
        persist()
    }

    var selected: Server? { servers.first { $0.id == selectedID } }

    func save(_ server: Server) {
        guard let url = Server.validatedURL(server.address) else { return }
        var normalized = server
        normalized.address = url.absoluteString
        normalized.name = server.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalized.name.isEmpty { normalized.name = url.host ?? "LongX" }
        if let index = servers.firstIndex(where: { $0.id == server.id }) { servers[index] = normalized }
        else { servers.append(normalized) }
        selectedID = normalized.id
        persist()
    }

    func remove(_ id: UUID) {
        servers.removeAll { $0.id == id }
        if selectedID == id { selectedID = servers.first?.id }
        persist()
    }

    func select(_ index: Int) {
        guard servers.indices.contains(index) else { return }
        selectedID = servers[index].id
    }

    private func persist() {
        do {
            defaults.set(try JSONEncoder().encode(servers), forKey: "servers")
            defaults.set(selectedID?.uuidString, forKey: "selectedServer")
            persistenceError = nil
        } catch { persistenceError = error.localizedDescription }
    }
}
