import SwiftUI
import WebKit

/// WKWebView, der die gemeinsame Touch Bar bereitstellt.
final class ControlWebView: WKWebView {
    var touchBarProvider: (() -> NSTouchBar?)?

    override func makeTouchBar() -> NSTouchBar? {
        touchBarProvider?() ?? super.makeTouchBar()
    }
}

/// Zeigt die WebView des gewählten Tabs, mit abgerundeten Ecken.
struct TabWebView: NSViewRepresentable {
    let tab: BrowserTab

    func makeNSView(context: Context) -> NSView {
        let container = NSView()
        container.wantsLayer = true
        container.layer?.cornerRadius = 14
        container.layer?.cornerCurve = .continuous
        container.layer?.masksToBounds = true
        attach(to: container)
        return container
    }

    func updateNSView(_ container: NSView, context: Context) {
        if container.subviews.first !== tab.webView {
            container.subviews.forEach { $0.removeFromSuperview() }
            attach(to: container)
        }
    }

    private func attach(to container: NSView) {
        tab.webView.frame = container.bounds
        tab.webView.autoresizingMask = [.width, .height]
        container.addSubview(tab.webView)
    }
}
