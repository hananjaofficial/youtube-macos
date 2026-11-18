import SwiftUI
import WebKit

/// WKWebView, der die gemeinsame Touch Bar bereitstellt.
final class ControlWebView: WKWebView {
    var touchBarProvider: (() -> NSTouchBar?)?

    override func makeTouchBar() -> NSTouchBar? {
        touchBarProvider?() ?? super.makeTouchBar()
    }
}

/// Bettet die transparente YouTube-Engine in SwiftUI ein.
struct YouTubeWebView: NSViewRepresentable {
    func makeNSView(context: Context) -> ControlWebView {
        YouTubeEngine.shared.webView
    }

    func updateNSView(_ nsView: ControlWebView, context: Context) {}
}
