import SwiftUI
import WebKit
import Observation

/// Ein Browser-Tab (= ein natives macOS-Fenster-Tab) mit eigener transparenter WebView.
@Observable
@MainActor
final class BrowserTab: NSObject, Identifiable, WKNavigationDelegate, WKUIDelegate {
    let id = UUID()
    var title = "hanstePlayer"
    var urlString = ""
    var canGoBack = false
    var isLoading = false
    var hasVideo = false
    var isPlaying = false
    var videoTitle = ""

    @ObservationIgnored let webView: ControlWebView
    @ObservationIgnored private var observations: [NSKeyValueObservation] = []

    private static let safariUA =
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Safari/605.1.15"

    init(url: URL) {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()   // persistenter Login für alle Tabs
        config.mediaTypesRequiringUserActionForPlayback = []
        config.preferences.isElementFullscreenEnabled = true
        config.userContentController.addUserScript(
            WKUserScript(source: EngineScripts.transform, injectionTime: .atDocumentStart, forMainFrameOnly: true)
        )
        webView = ControlWebView(frame: .zero, configuration: config)
        super.init()

        webView.customUserAgent = Self.safariUA
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        makeTransparent()
        webView.touchBarProvider = { TouchBarController.shared.touchBar }

        observations = [watch(\.url), watch(\.title), watch(\.canGoBack), watch(\.isLoading)]
        webView.load(URLRequest(url: url))
    }

    /// Kein eigener Hintergrund: Der Fenster-Blur scheint durch.
    private func makeTransparent() {
        webView.underPageBackgroundColor = .clear
        if webView.responds(to: NSSelectorFromString("_setDrawsBackground:")) {
            webView.setValue(false, forKey: "drawsBackground")
        }
        webView.wantsLayer = true
        webView.layer?.backgroundColor = NSColor.clear.cgColor
    }

    private func watch<V>(_ keyPath: KeyPath<ControlWebView, V>) -> NSKeyValueObservation {
        webView.observe(keyPath) { [weak self] _, _ in
            Task { @MainActor in self?.syncNav() }
        }
    }

    var service: Service? { Service.from(url: URL(string: urlString)) }

    private func syncNav() {
        urlString = webView.url?.absoluteString ?? ""
        canGoBack = webView.canGoBack
        isLoading = webView.isLoading
        let cleaned = Self.cleanTitle(webView.title ?? "")
        title = cleaned.isEmpty ? (service?.name ?? "hanstePlayer") : cleaned
    }

    private static func cleanTitle(_ raw: String) -> String {
        raw.replacingOccurrences(of: #"^\(\d+\)\s*"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\s*-\s*YouTube$"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
    }

    // MARK: - Navigation

    func load(_ url: URL) {
        if Service.isInternal(url.host) {
            webView.load(URLRequest(url: url))
        } else {
            NSWorkspace.shared.open(url)
        }
    }

    func goBack() { if webView.canGoBack { webView.goBack() } }

    func shutdown() {
        observations.removeAll()
        webView.navigationDelegate = nil
        webView.uiDelegate = nil
        webView.loadHTMLString("", baseURL: nil)
    }

    // MARK: - Player

    func togglePlayPause() { run(EngineScripts.togglePlay) }
    func seek(by seconds: Double) { run(EngineScripts.seek(seconds)) }
    func togglePiP() { run(EngineScripts.pip) }

    private func run(_ js: String) {
        webView.evaluateJavaScript("(function(){ try { \(js) } catch(e) {} })();", completionHandler: nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in self?.refreshPlayer() }
    }

    func refreshPlayer() {
        webView.evaluateJavaScript(EngineScripts.stateQuery) { [weak self] result, _ in
            guard let str = result as? String,
                  let data = str.data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Bool] else { return }
            Task { @MainActor in
                guard let self else { return }
                let has = obj["hasVideo"] ?? false
                let playing = obj["playing"] ?? false
                let shown = has ? self.title : ""
                if self.hasVideo != has { self.hasVideo = has }
                if self.isPlaying != playing { self.isPlaying = playing }
                if self.videoTitle != shown { self.videoTitle = shown }
            }
        }
    }

    // MARK: - Delegates

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
        if navigationAction.navigationType == .linkActivated,
           let url = navigationAction.request.url, !Service.isInternal(url.host) {
            NSWorkspace.shared.open(url)
            return .cancel
        }
        return .allow
    }

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if navigationAction.targetFrame == nil, let url = navigationAction.request.url {
            TabStore.shared.openNewTab(url: url)
        }
        return nil
    }
}
