import AppKit
import Combine

extension NSTouchBarItem.Identifier {
    static let back10 = NSTouchBarItem.Identifier("com.local.youtube-mini.back10")
    static let playPause = NSTouchBarItem.Identifier("com.local.youtube-mini.playPause")
    static let forward10 = NSTouchBarItem.Identifier("com.local.youtube-mini.forward10")
    static let videoTitle = NSTouchBarItem.Identifier("com.local.youtube-mini.videoTitle")
}

@MainActor
final class TouchBarController: NSObject, NSTouchBarDelegate {
    static let shared = TouchBarController()

    private let player = PlayerController.shared
    private var cancellables = Set<AnyCancellable>()

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
        playButton.image = Self.symbol("play.fill")
        playButton.target = self
        playButton.action = #selector(playPause)

        player.$title
            .sink { [weak self] title in
                self?.titleLabel.stringValue = title.isEmpty ? "YouTube" : title
            }
            .store(in: &cancellables)

        player.$isPlaying
            .sink { [weak self] playing in
                self?.playButton.image = Self.symbol(playing ? "pause.fill" : "play.fill")
            }
            .store(in: &cancellables)
    }

    /// Hängt die Touch Bar an das Fenster (und an den WebView, falls dieser den Fokus hat).
    func attach(to window: NSWindow) {
        window.touchBar = touchBar
        player.webView.touchBarProvider = { [weak self] in self?.touchBar }
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

    // MARK: - Helfer

    private func buttonItem(_ id: NSTouchBarItem.Identifier,
                            symbol name: String,
                            action: Selector) -> NSCustomTouchBarItem {
        let item = NSCustomTouchBarItem(identifier: id)
        item.view = NSButton(image: Self.symbol(name), target: self, action: action)
        return item
    }

    private static func symbol(_ name: String) -> NSImage {
        NSImage(systemSymbolName: name, accessibilityDescription: nil) ?? NSImage()
    }

    @objc private func playPause() { player.togglePlayPause() }
    @objc private func back() { player.seek(by: -10) }
    @objc private func forward() { player.seek(by: 10) }
}
