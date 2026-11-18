import SwiftUI
import WebKit
import Observation

enum YTSection { case home, shorts, subs, other }

/// Eigentliche YouTube-Webseite, transparent und ohne Web-Header.
@Observable
@MainActor
final class YouTubeEngine: NSObject, WKNavigationDelegate, WKUIDelegate {
    static let shared = YouTubeEngine()

    var title = ""
    var isPlaying = false
    var hasVideo = false
    var urlString = ""
    var canGoBack = false

    @ObservationIgnored let webView: ControlWebView
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var urlObservation: NSKeyValueObservation?

    private static let safariUA =
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Safari/605.1.15"

    private override init() {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()   // persistenter Google-Login
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
        webView.underPageBackgroundColor = .clear
        if webView.responds(to: NSSelectorFromString("_setDrawsBackground:")) {
            webView.setValue(false, forKey: "drawsBackground")
        }

        urlObservation = webView.observe(\.url, options: [.new]) { [weak self] _, _ in
            Task { @MainActor in
                guard let self else { return }
                self.urlString = self.webView.url?.absoluteString ?? ""
                self.canGoBack = self.webView.canGoBack
            }
        }
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        goHome()
    }

    var section: YTSection {
        guard let path = URL(string: urlString)?.path else { return .other }
        if path.hasPrefix("/shorts") { return .shorts }
        if path.hasPrefix("/feed/subscriptions") { return .subs }
        if path.isEmpty || path == "/" { return .home }
        return .other
    }

    // MARK: - Navigation

    func goHome() { load(URL(string: "https://www.youtube.com/")!) }
    func goShorts() { load(URL(string: "https://www.youtube.com/shorts")!) }
    func goSubs() { load(URL(string: "https://www.youtube.com/feed/subscriptions")!) }
    func goBack() { if webView.canGoBack { webView.goBack() } }

    /// Suchtext oder YouTube-Link.
    func open(_ input: String) {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        if text.hasPrefix("http://") || text.hasPrefix("https://"), let url = URL(string: text) {
            load(url)
        } else if text.contains("youtube.com") || text.contains("youtu.be"), let url = URL(string: "https://" + text) {
            load(url)
        } else {
            var c = URLComponents(string: "https://www.youtube.com/results")!
            c.queryItems = [URLQueryItem(name: "search_query", value: text)]
            if let url = c.url { load(url) }
        }
    }

    private func load(_ url: URL) {
        if Self.isInternal(url.host) {
            webView.load(URLRequest(url: url))
        } else {
            NSWorkspace.shared.open(url)
        }
    }

    private static func isInternal(_ host: String?) -> Bool {
        guard let h = host?.lowercased() else { return false }
        return h.contains("youtube.") || h.contains("google.") || h == "youtu.be" || h.hasSuffix("gstatic.com")
    }

    // MARK: - Steuerung des HTML5-Players

    func togglePlayPause() { run(EngineScripts.togglePlay) }
    func seek(by seconds: Double) { run(EngineScripts.seek(seconds)) }
    func togglePiP() { run(EngineScripts.pip) }

    private func run(_ js: String) {
        webView.evaluateJavaScript("(function(){ try { \(js) } catch(e) {} })();", completionHandler: nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in self?.refresh() }
    }

    func refresh() {
        webView.evaluateJavaScript(EngineScripts.stateQuery) { [weak self] result, _ in
            guard let str = result as? String,
                  let data = str.data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
            Task { @MainActor in
                guard let self else { return }
                let t = (obj["title"] as? String) ?? ""
                let has = (obj["hasVideo"] as? Bool) ?? false
                let playing = (obj["playing"] as? Bool) ?? false
                let shown = has && t != "YouTube" ? t : ""
                if self.title != shown { self.title = shown }
                if self.hasVideo != has { self.hasVideo = has }
                if self.isPlaying != playing { self.isPlaying = playing }
                if self.canGoBack != self.webView.canGoBack { self.canGoBack = self.webView.canGoBack }
            }
        }
    }

    // MARK: - Delegates

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
        if navigationAction.navigationType == .linkActivated,
           let url = navigationAction.request.url, !Self.isInternal(url.host) {
            NSWorkspace.shared.open(url)
            return .cancel
        }
        return .allow
    }

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if navigationAction.targetFrame == nil, let url = navigationAction.request.url { load(url) }
        return nil
    }
}
