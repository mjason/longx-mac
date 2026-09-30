import SwiftUI
import WebKit

// Only web-owned chords bypass the AppKit menu. Editing, IME and system keys retain native handling.
final class LongXWebView: WKWebView {
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let key = event.charactersIgnoringModifiers?.lowercased() ?? ""
        if flags.contains(.command), !flags.contains(.control),
           !(flags.contains(.shift) && key == "w"),
           (!flags.contains(.option) && ["k", "t", "w", "s", "1", "2", "3", "4"].contains(key)
            || flags.contains(.option) && [123, 124].contains(Int(event.keyCode))) {
            keyDown(with: event)
            return true
        }
        if flags.contains(.control), event.keyCode == 48 {
            keyDown(with: event)
            return true
        }
        return super.performKeyEquivalent(with: event)
    }
}

@MainActor
private final class ChromeMessageHandler: NSObject, WKScriptMessageHandler {
    weak var session: WebSession?
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.frameInfo.isMainFrame, let payload = message.body as? [String: String] else { return }
        session?.updateChrome(payload)
    }
}

@MainActor
final class WebSession: NSObject, ObservableObject, WKNavigationDelegate, WKUIDelegate, WKDownloadDelegate {
    @Published var server: Server
    let webView: LongXWebView
    @Published var error: String?
    @Published var loading = true
    @Published var progress = 0.0
    @Published var chromeColor = Color(nsColor: .windowBackgroundColor)
    @Published var preferredScheme: ColorScheme?
    private let chromeHandler = ChromeMessageHandler()
    private var observations: [NSKeyValueObservation] = []
    private var downloads: [WKDownload] = []

    init(server: Server) {
        self.server = server
        let config = WKWebViewConfiguration()
        // Persistent profiles isolate cookies/local storage even for two entries on the same host.
        config.websiteDataStore = WKWebsiteDataStore(forIdentifier: server.id)
        config.preferences.javaScriptCanOpenWindowsAutomatically = true
        let script = """
        (() => {
          const mark = () => {
            if (!document.documentElement) return false;
            document.documentElement.setAttribute('data-app-window', 'macos');
            return true;
          };
          if (!mark()) {
            const observer = new MutationObserver(() => { if (mark()) observer.disconnect(); });
            observer.observe(document, { childList: true });
          }
        })();
        """
        config.userContentController.addUserScript(WKUserScript(source: script, injectionTime: .atDocumentStart, forMainFrameOnly: true))
        webView = LongXWebView(frame: .zero, configuration: config)
        super.init()
        chromeHandler.session = self
        config.userContentController.add(chromeHandler, name: "longxChrome")
        let chromeScript = """
        (() => {
          let last = '';
          let scheduled = false;
          const sync = () => {
            scheduled = false;
            const root = document.documentElement;
            const frameToken = location.pathname.startsWith('/p/') ? '--sidebar' : '--background';
            const payload = {
              frame: getComputedStyle(root).getPropertyValue(frameToken).trim(),
              page: location.href,
              preference: localStorage.getItem('longx:theme') || 'system'
            };
            const encoded = JSON.stringify(payload);
            if (encoded === last) return;
            last = encoded;
            window.webkit.messageHandlers.longxChrome.postMessage(payload);
          };
          new MutationObserver(sync).observe(document.documentElement, { attributes: true, attributeFilter: ['data-theme', 'class', 'style'] });
          const schedule = () => {
            if (!scheduled) { scheduled = true; requestAnimationFrame(sync); }
          };
          window.__longxRefreshChrome = () => {
            last = '';
            sync();
            schedule();
          };
          new MutationObserver(schedule).observe(document.body, { childList: true, subtree: true, attributes: true, attributeFilter: ['class', 'style'] });
          new MutationObserver(schedule).observe(document.head, { childList: true, subtree: true, attributes: true });
          window.addEventListener('popstate', schedule);
          matchMedia('(prefers-color-scheme: dark)').addEventListener('change', sync);
          window.addEventListener('load', sync);
          sync();
        })();
        """
        config.userContentController.addUserScript(WKUserScript(source: chromeScript, injectionTime: .atDocumentEnd, forMainFrameOnly: true))
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        observations = [
            webView.observe(\.url, options: [.new]) { [weak self] _, _ in
                Task { @MainActor in self?.refreshChrome() }
            },
            webView.observe(\.isLoading, options: [.new]) { [weak self] view, _ in
                Task { @MainActor in self?.loading = view.isLoading }
            },
            webView.observe(\.estimatedProgress, options: [.new]) { [weak self] view, _ in
                Task { @MainActor in self?.progress = view.estimatedProgress }
            }
        ]
        webView.load(URLRequest(url: server.url))
    }

    fileprivate func updateChrome(_ payload: [String: String]) {
        if let hex = payload["frame"], hex.count == 7, hex.hasPrefix("#"),
           let value = UInt32(hex.dropFirst(), radix: 16) {
            chromeColor = Color(red: Double((value >> 16) & 255) / 255,
                                green: Double((value >> 8) & 255) / 255,
                                blue: Double(value & 255) / 255)
        }
        switch payload["preference"] {
        case "dark": preferredScheme = .dark
        case "light": preferredScheme = .light
        default: preferredScheme = nil
        }
    }

    private func refreshChrome() {
        webView.evaluateJavaScript("window.__longxRefreshChrome?.()", completionHandler: nil)
    }

    func reload() { error = nil; webView.reload() }
    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) { refreshChrome() }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { refreshChrome() }
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) { error = nil }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError failure: Error) { failed(failure) }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError failure: Error) { failed(failure) }
    private func failed(_ failure: Error) {
        guard (failure as NSError).code != NSURLErrorCancelled else { return }
        error = failure.localizedDescription
        loading = false
    }
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        error = String(localized: "The web process has stopped. Please reload.")
    }
    private func sameOrigin(_ url: URL) -> Bool {
        let base = server.url
        return url.scheme == base.scheme && url.host == base.host && (url.port ?? (url.scheme == "https" ? 443 : 80)) == (base.port ?? (base.scheme == "https" ? 443 : 80))
    }
    private func openExternal(_ url: URL) {
        guard ["https", "http", "mailto"].contains(url.scheme?.lowercased() ?? "") else { return }
        NSWorkspace.shared.open(url)
    }
    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = action.request.url else { decisionHandler(.cancel); return }
        if action.shouldPerformDownload { decisionHandler(.download); return }
        if action.navigationType == .linkActivated, action.targetFrame?.isMainFrame != false, !sameOrigin(url) {
            openExternal(url); decisionHandler(.cancel); return
        }
        if !["http", "https", "about", "blob", "data"].contains(url.scheme ?? "") {
            openExternal(url); decisionHandler(.cancel); return
        }
        decisionHandler(.allow)
    }
    func webView(_ webView: WKWebView, decidePolicyFor response: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        decisionHandler(response.canShowMIMEType ? .allow : .download)
    }
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for action: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let url = action.request.url {
            if sameOrigin(url) { webView.load(action.request) } else { openExternal(url) }
        }
        return nil
    }
    func webView(_ webView: WKWebView, runOpenPanelWith parameters: WKOpenPanelParameters, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping ([URL]?) -> Void) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = parameters.allowsMultipleSelection
        panel.canChooseDirectories = parameters.allowsDirectories
        panel.begin { result in completionHandler(result == .OK ? panel.urls : nil) }
    }
    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        let alert = NSAlert(); alert.messageText = message
        alert.runModal(); completionHandler()
    }
    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        let alert = NSAlert(); alert.messageText = message
        alert.addButton(withTitle: String(localized: "OK")); alert.addButton(withTitle: String(localized: "Cancel"))
        completionHandler(alert.runModal() == .alertFirstButtonReturn)
    }
    func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (String?) -> Void) {
        let alert = NSAlert(); alert.messageText = prompt
        let input = NSTextField(string: defaultText ?? ""); input.frame = NSRect(x: 0, y: 0, width: 280, height: 24)
        alert.accessoryView = input; alert.addButton(withTitle: String(localized: "OK")); alert.addButton(withTitle: String(localized: "Cancel"))
        completionHandler(alert.runModal() == .alertFirstButtonReturn ? input.stringValue : nil)
    }
    func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) { retain(download) }
    func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload) { retain(download) }
    private func retain(_ download: WKDownload) { downloads.append(download); download.delegate = self }
    func download(_ download: WKDownload, decideDestinationUsing response: URLResponse, suggestedFilename: String, completionHandler: @escaping (URL?) -> Void) {
        let panel = NSSavePanel(); panel.nameFieldStringValue = suggestedFilename
        panel.begin { result in completionHandler(result == .OK ? panel.url : nil) }
    }
    func downloadDidFinish(_ download: WKDownload) { downloads.removeAll { $0 === download } }
    func download(_ download: WKDownload, didFailWithError failure: Error, resumeData: Data?) {
        error = String(format: String(localized: "Download failed: %@"), failure.localizedDescription); downloads.removeAll { $0 === download }
    }
}

@MainActor
final class SessionPool: ObservableObject {
    private var sessions: [UUID: WebSession] = [:]
    func session(for server: Server) -> WebSession {
        if let cached = sessions[server.id], cached.server.address == server.address {
            if cached.server != server { cached.server = server }
            return cached
        }
        sessions[server.id]?.webView.stopLoading()
        let session = WebSession(server: server)
        sessions[server.id] = session
        return session
    }
    func remove(_ id: UUID) {
        sessions.removeValue(forKey: id)?.webView.stopLoading()
        WKWebsiteDataStore.remove(forIdentifier: id) { _ in }
    }
}

struct WebSurface: NSViewRepresentable {
    let webView: WKWebView
    func makeNSView(context: Context) -> NSView { NSView() }
    func updateNSView(_ host: NSView, context: Context) {
        guard webView.superview !== host else { return }
        host.subviews.forEach { $0.removeFromSuperview() }
        webView.removeFromSuperview()
        host.addSubview(webView)
        webView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            webView.leadingAnchor.constraint(equalTo: host.leadingAnchor), webView.trailingAnchor.constraint(equalTo: host.trailingAnchor),
            webView.topAnchor.constraint(equalTo: host.topAnchor), webView.bottomAnchor.constraint(equalTo: host.bottomAnchor)
        ])
        DispatchQueue.main.async { host.window?.makeFirstResponder(webView) }
    }
}
