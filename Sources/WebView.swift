import SwiftUI
import WebKit

/// WKWebView, der die gemeinsame Touch Bar bereitstellt.
final class ControlWebView: WKWebView {
    var touchBarProvider: (() -> NSTouchBar?)?

    override func makeTouchBar() -> NSTouchBar? {
        touchBarProvider?() ?? super.makeTouchBar()
    }
}

@MainActor
final class PlayerController: NSObject, ObservableObject, WKNavigationDelegate, WKUIDelegate {
    static let shared = PlayerController()

    @Published var title = ""
    @Published var isPlaying = false
    @Published var urlString = ""

    let webView: ControlWebView
    private var timer: Timer?

    private static let safariUA =
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Safari/605.1.15"

    private override init() {
        let config = WKWebViewConfiguration()
        config.mediaTypesRequiringUserActionForPlayback = []
        config.preferences.isElementFullscreenEnabled = true
        webView = ControlWebView(frame: .zero, configuration: config)
        super.init()

        webView.customUserAgent = Self.safariUA
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = true

        webView.load(URLRequest(url: URL(string: "https://www.youtube.com")!))

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    // MARK: - Navigation

    func load(input: String) {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        if text.hasPrefix("http://") || text.hasPrefix("https://"), let url = URL(string: text) {
            webView.load(URLRequest(url: url))
        } else if text.contains("youtube.com") || text.contains("youtu.be"),
                  let url = URL(string: "https://" + text) {
            webView.load(URLRequest(url: url))
        } else {
            var comps = URLComponents(string: "https://www.youtube.com/results")!
            comps.queryItems = [URLQueryItem(name: "search_query", value: text)]
            if let url = comps.url { webView.load(URLRequest(url: url)) }
        }
    }

    // MARK: - Steuerung per JavaScript

    func togglePlayPause() {
        run("var v=document.querySelector('video'); if(v){ if(v.paused){v.play();}else{v.pause();} }")
    }

    func seek(by seconds: Double) {
        run("var v=document.querySelector('video'); if(v){ v.currentTime=Math.max(0, v.currentTime + (\(seconds))); }")
        refreshSoon()
    }

    private func run(_ js: String) {
        webView.evaluateJavaScript("(function(){\(js)})();", completionHandler: nil)
        refreshSoon()
    }

    private func refreshSoon() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            self?.refresh()
        }
    }

    /// Liest Videotitel und Wiedergabestatus aus der Seite.
    func refresh() {
        let js = """
        (function(){
          var v = document.querySelector('video');
          var t = document.title.replace(/^\\(\\d+\\)\\s*/, '').replace(/\\s*-\\s*YouTube$/, '');
          return JSON.stringify({title: t, playing: !!v && !v.paused && !v.ended, hasVideo: !!v});
        })();
        """
        webView.evaluateJavaScript(js) { [weak self] result, _ in
            guard let self,
                  let str = result as? String,
                  let data = str.data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            else { return }
            Task { @MainActor in
                let isVideo = (obj["hasVideo"] as? Bool) ?? false
                let t = (obj["title"] as? String) ?? ""
                let newTitle = isVideo && t != "YouTube" ? t : ""
                if self.title != newTitle { self.title = newTitle }
                let playing = (obj["playing"] as? Bool) ?? false
                if self.isPlaying != playing { self.isPlaying = playing }
                if let u = self.webView.url?.absoluteString, self.urlString != u { self.urlString = u }
            }
        }
    }

    // MARK: - WKNavigationDelegate / WKUIDelegate

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        refresh()
    }

    func webView(_ webView: WKWebView,
                 createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction,
                 windowFeatures: WKWindowFeatures) -> WKWebView? {
        // Links mit target=_blank im selben Fenster öffnen.
        if navigationAction.targetFrame == nil {
            webView.load(navigationAction.request)
        }
        return nil
    }
}

struct WebViewContainer: NSViewRepresentable {
    func makeNSView(context: Context) -> ControlWebView {
        PlayerController.shared.webView
    }

    func updateNSView(_ nsView: ControlWebView, context: Context) {}
}
