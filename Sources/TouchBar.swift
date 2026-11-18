import AppKit
import Observation

extension NSTouchBarItem.Identifier {
    static let back10 = NSTouchBarItem.Identifier("com.local.youtube-mini.back10")
    static let playPause = NSTouchBarItem.Identifier("com.local.youtube-mini.playPause")
    static let forward10 = NSTouchBarItem.Identifier("com.local.youtube-mini.forward10")
    static let videoTitle = NSTouchBarItem.Identifier("com.local.youtube-mini.videoTitle")
}

/// Touch Bar, gekoppelt an den HTML5-Player der YouTube-Engine.
@MainActor
final class TouchBarController: NSObject, NSTouchBarDelegate {
    static let shared = TouchBarController()

    private let engine = YouTubeEngine.shared

    private let titleLabel: NSTextField = {
        let label = NSTextField(labelWithString: "YouTube")
        label.lineBreakMode = .byTruncatingTail
        label.font = .systemFont(ofSize: 13)
        label.textColor = .white
        return label
    }()
    private let playButton = NSButton()

    private lazy var touchBar: NSTouchBar = {
        let bar = NSTouchBar()
        bar.delegate = self
        bar.defaultItemIdentifiers = [.back10, .playPause, .forward10, .videoTitle]
        return bar
    }()

    private override init() {
        super.init()
        playButton.target = self
        playButton.action = #selector(playPause)
        sync()
        track()
    }

    /// Hängt die Touch Bar an das Fenster (und an den WebView, falls dieser den Fokus hat).
    func attach(to window: NSWindow) {
        window.touchBar = touchBar
        engine.webView.touchBarProvider = { [weak self] in self?.touchBar }
    }

    private func sync() {
        titleLabel.stringValue = engine.title.isEmpty ? "YouTube" : engine.title
        playButton.image = Self.symbol(engine.isPlaying ? "pause.fill" : "play.fill")
    }

    private func track() {
        withObservationTracking {
            _ = engine.title
            _ = engine.isPlaying
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.sync()
                self?.track()
            }
        }
    }

    // MARK: - NSTouchBarDelegate

    func touchBar(_ touchBar: NSTouchBar,
                  makeItemForIdentifier identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem? {
        switch identifier {
        case .back10:
            return buttonItem(identifier, symbol: "gobackward.10", action: #selector(back))
        case .forward10:
            return buttonItem(identifier, symbol: "goforward.10", action: #selector(forward))
        case .playPause:
            let item = NSCustomTouchBarItem(identifier: identifier)
            item.view = playButton
            return item
        case .videoTitle:
            let item = NSCustomTouchBarItem(identifier: identifier)
            titleLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 300).isActive = true
            item.view = titleLabel
            return item
        default:
            return nil
        }
    }

    private func buttonItem(_ id: NSTouchBarItem.Identifier, symbol name: String, action: Selector) -> NSCustomTouchBarItem {
        let item = NSCustomTouchBarItem(identifier: id)
        item.view = NSButton(image: Self.symbol(name), target: self, action: action)
        return item
    }

    private static func symbol(_ name: String) -> NSImage {
        NSImage(systemSymbolName: name, accessibilityDescription: nil) ?? NSImage()
    }

    @objc private func playPause() { engine.togglePlayPause() }
    @objc private func back() { engine.seek(by: -10) }
    @objc private func forward() { engine.seek(by: 10) }
}
