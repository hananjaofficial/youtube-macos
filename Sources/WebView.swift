import SwiftUI
import WebKit

/// WKWebView, der die gemeinsame Touch Bar bereitstellt.
final class ControlWebView: WKWebView {
    var touchBarProvider: (() -> NSTouchBar?)?

    override func makeTouchBar() -> NSTouchBar? {
        touchBarProvider?() ?? super.makeTouchBar()
    }
}

/// Steuert den eingebetteten, rahmenlosen YouTube-Player (IFrame Player API, ohne Header/Kommentare/Seitenleisten).
@MainActor
final class PlayerController: NSObject, ObservableObject, WKScriptMessageHandler {
    static let shared = PlayerController()

    @Published var current: Video?
    @Published var title = ""
    @Published var isPlaying = false
    @Published var errorText: String?

    let webView: ControlWebView
    private var timer: Timer?

    private static let safariUA =
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Safari/605.1.15"

    private override init() {
        let config = WKWebViewConfiguration()
        config.mediaTypesRequiringUserActionForPlayback = []
        webView = ControlWebView(frame: .zero, configuration: config)
        super.init()
        webView.customUserAgent = Self.safariUA
        webView.configuration.userContentController.add(self, name: "ytError")

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    // MARK: - Wiedergabe

    func play(_ video: Video) {
        current = video
        title = video.title
        isPlaying = false
        errorText = nil
        webView.loadHTMLString(Self.html(for: video.id), baseURL: URL(string: "https://www.youtube.com"))
    }

    func close() {
        current = nil
        title = ""
        isPlaying = false
        errorText = nil
        webView.loadHTMLString("", baseURL: nil)
    }

    func openInBrowser() {
        guard let id = current?.id, let url = URL(string: "https://www.youtube.com/watch?v=\(id)") else { return }
        NSWorkspace.shared.open(url)
    }

    // MARK: - Steuerung per JavaScript

    func togglePlayPause() {
        run("if(player&&player.getPlayerState){ var s=player.getPlayerState(); if(s===1||s===3){player.pauseVideo();}else{player.playVideo();} }")
    }

    func seek(by seconds: Double) {
        run("if(player&&player.seekTo){ player.seekTo(player.getCurrentTime() + (\(seconds)), true); }")
    }

    private func run(_ js: String) {
        webView.evaluateJavaScript("(function(){ try { \(js) } catch(e) {} })();", completionHandler: nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in self?.refresh() }
    }

    /// Liest Videotitel und Wiedergabestatus aus dem Player.
    func refresh() {
        guard current != nil else { return }
        webView.evaluateJavaScript("typeof ytState === 'function' ? ytState() : '{}'") { [weak self] result, _ in
            guard let self,
                  let str = result as? String,
                  let data = str.data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            else { return }
            Task { @MainActor in
                if let t = obj["title"] as? String, !t.isEmpty, self.title != t { self.title = t }
                let state = (obj["state"] as? Int) ?? -1
                let playing = state == 1 || state == 3
                if self.isPlaying != playing { self.isPlaying = playing }
            }
        }
    }

    func userContentController(_ userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage) {
        guard message.name == "ytError" else { return }
        errorText = "Dieses Video lässt sich nicht einbetten (Fehler \(message.body))."
    }

    // MARK: - Player-Seite

    private static func html(for id: String) -> String {
        """
        <!DOCTYPE html><html><head><meta charset="utf-8">
        <meta name="viewport" content="width=device-width,initial-scale=1">
        <style>html,body{margin:0;height:100%;background:#000;overflow:hidden}#p{position:absolute;inset:0;width:100%;height:100%}</style>
        </head><body><div id="p"></div>
        <script src="https://www.youtube.com/iframe_api"></script>
        <script>
        var player;
        function onYouTubeIframeAPIReady(){
          player = new YT.Player('p', {
            width:'100%', height:'100%', videoId:'\(id)',
            playerVars:{autoplay:1, playsinline:1, rel:0, controls:0, modestbranding:1, fs:0, iv_load_policy:3, disablekb:1},
            events:{ onError:function(e){ window.webkit.messageHandlers.ytError.postMessage(String(e.data)); } }
          });
        }
        function ytState(){
          if(!player || !player.getPlayerState){ return '{}'; }
          var d = player.getVideoData ? player.getVideoData() : {};
          return JSON.stringify({title:(d && d.title) || '', state:player.getPlayerState()});
        }
        </script></body></html>
        """
    }
}

struct WebViewContainer: NSViewRepresentable {
    func makeNSView(context: Context) -> ControlWebView {
        PlayerController.shared.webView
    }

    func updateNSView(_ nsView: ControlWebView, context: Context) {}
}
