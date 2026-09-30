import XCTest
import SwiftUI
@testable import LongX

final class ServerTests: XCTestCase {
    func testAddressValidation() {
        XCTAssertEqual(Server.validatedURL(" longx.diz.plus:7443 ")?.absoluteString, "https://longx.diz.plus:7443")
        XCTAssertNotNil(Server.validatedURL("http://localhost:7788"))
        XCTAssertNil(Server.validatedURL("javascript:alert(1)"))
        XCTAssertNil(Server.validatedURL("https://user:password@example.com"))
        XCTAssertNil(Server.validatedURL("https://"))
    }

    @MainActor func testPersistenceSelectionAndRemoval() {
        let suite = "LongXTests.\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = ServerStore(defaults: defaults)
        let initialID = store.selectedID
        let second = Server(name: "Local", address: "http://localhost:7788")
        store.save(second)
        XCTAssertEqual(store.servers.count, 2)
        XCTAssertEqual(store.selectedID, second.id)
        let restored = ServerStore(defaults: defaults)
        XCTAssertEqual(restored.selectedID, second.id)
        restored.remove(second.id)
        XCTAssertEqual(restored.selectedID, initialID)
        restored.remove(initialID!)
        XCTAssertNil(restored.selectedID)
        XCTAssertTrue(ServerStore(defaults: defaults).servers.isEmpty)
    }

    @MainActor func testSessionReuseAndAddressInvalidation() {
        let pool = SessionPool()
        var server = Server(name: "Test", address: "http://127.0.0.1:1")
        let first = pool.session(for: server)
        XCTAssertTrue(first === pool.session(for: server))
        server.name = "Renamed"
        XCTAssertTrue(first === pool.session(for: server))
        server.address = "http://127.0.0.1:2"
        XCTAssertFalse(first === pool.session(for: server))
        pool.remove(server.id)
    }

    @MainActor func testChromeRefreshForRouteAndPageStyleChanges() async throws {
        let session = WebSession(server: Server(name: "Chrome", address: "http://127.0.0.1:1"))
        session.webView.loadHTMLString("""
        <html style="--background:#ffffff;--sidebar:#15171c"><head></head><body>Page</body></html>
        """, baseURL: URL(string: "http://127.0.0.1:1/"))
        func waitForColor(_ expected: Color) async throws {
            for _ in 0..<200 {
                if session.chromeColor == expected { return }
                try await Task.sleep(nanoseconds: 10_000_000)
            }
            XCTFail("Toolbar color did not refresh")
        }
        try await waitForColor(Color(red: 1, green: 1, blue: 1))
        _ = try await session.webView.evaluateJavaScript("history.pushState({}, '', '/p/test')")
        try await waitForColor(Color(red: 21.0 / 255, green: 23.0 / 255, blue: 28.0 / 255))
        _ = try await session.webView.evaluateJavaScript("document.documentElement.style.setProperty('--sidebar', '#262931')")
        try await waitForColor(Color(red: 38.0 / 255, green: 41.0 / 255, blue: 49.0 / 255))
        _ = try await session.webView.evaluateJavaScript("history.replaceState({}, '', '/')")
        try await waitForColor(Color(red: 1, green: 1, blue: 1))
        session.webView.stopLoading()
    }

}
