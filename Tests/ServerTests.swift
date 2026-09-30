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

    @MainActor func testChromeBridgeReceivesWebpageValues() async throws {
        let session = WebSession(server: Server(name: "Chrome", address: "http://127.0.0.1:1"))
        session.webView.loadHTMLString("<html><body>Page</body></html>", baseURL: URL(string: "http://127.0.0.1:1/"))
        var ready = false
        for _ in 0..<500 {
            if (try? await session.webView.evaluateJavaScript("typeof window.longxNative === 'object'")) as? Bool == true { ready = true; break }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTAssertTrue(ready)
        _ = try await session.webView.evaluateJavaScript("""
        window.addEventListener('longx:chrome-request', () => {
          window.longxNative.setChrome({background:'#15171c',theme:'dark'});
        });
        history.pushState({}, '', '/any-page');
        """)
        for _ in 0..<500 {
            if session.preferredScheme == .dark { break }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTAssertEqual(session.preferredScheme, .dark)
        XCTAssertEqual(session.chromeColor, Color(red: 21.0 / 255, green: 23.0 / 255, blue: 28.0 / 255))
        _ = try await session.webView.evaluateJavaScript("window.longxNative.setChrome({background:'#ffffff',theme:'light'})")
        for _ in 0..<500 {
            if session.preferredScheme == .light { break }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTAssertEqual(session.preferredScheme, .light)
        XCTAssertEqual(session.chromeColor, Color(red: 1, green: 1, blue: 1))
        session.webView.stopLoading()
    }

    @MainActor func testChromeRejectsMalformedPayloadsAndAllowsSystemTheme() {
        let session = WebSession(server: Server(name: "Chrome", address: "http://127.0.0.1:1"))
        session.updateChrome(["version": 1, "background": "#123456", "theme": "dark"])
        let color = session.chromeColor
        for payload: [String: Any] in [
            ["version": 2, "background": "#ffffff", "theme": "light"],
            ["version": 1, "background": "#xyzxyz", "theme": "light"],
            ["version": 1, "background": "#ffffff", "theme": "unknown"],
            ["background": "#ffffff", "theme": "light"]
        ] {
            session.updateChrome(payload)
            XCTAssertEqual(session.chromeColor, color)
            XCTAssertEqual(session.preferredScheme, .dark)
        }
        session.updateChrome(["version": 1, "background": "#ffffff", "theme": "system"])
        XCTAssertNil(session.preferredScheme)
        session.webView.stopLoading()
    }
}
