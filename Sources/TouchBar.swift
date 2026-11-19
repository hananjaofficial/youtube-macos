import AppKit
import Observation

extension NSTouchBarItem.Identifier {
    static let back10 = NSTouchBarItem.Identifier("de.hananja.hanstePlayer.back10")
    static let playPause = NSTouchBarItem.Identifier("de.hananja.hanstePlayer.playPause")
    static let forward10 = NSTouchBarItem.Identifier("de.hananja.hanstePlayer.forward10")
    static let videoTitle = NSTouchBarItem.Identifier("de.hananja.hanstePlayer.videoTitle")
}

/// Touch Bar, gekoppelt an den Player des gewählten Tabs.
@MainActor
final class TouchBarController: NSObject, NSTouchBarDelegate {
    static let shared = TouchBarController()

    private let store = TabStore.shared

    private let titleLabel: NSTextField = {
        let label = NSTextField(labelWithString: "hanstePlayer")
        label.lineBreakMode = .byTruncatingTail
        label.font = .systemFont(ofSize: 13)
        label.textColor = .white
        return label
    }()
    private let playButton = NSButton()

    lazy var touchBar: NSTouchBar = {
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

    /// Hängt die Touch Bar an das Fenster (die WebViews liefern sie über touchBarProvider).
    func attach(to window: NSWindow) {
        window.touchBar = touchBar
    }

    private func sync() {
        let title = store.current?.videoTitle ?? ""
        titleLabel.stringValue = title.isEmpty ? "hanstePlayer" : title
        playButton.image = Self.symbol((store.current?.isPlaying ?? false) ? "pause.fill" : "play.fill")
    }

    private func track() {
        withObservationTracking {
            _ = store.current?.videoTitle
            _ = store.current?.isPlaying
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

    @objc private func playPause() { store.current?.togglePlayPause() }
    @objc private func back() { store.current?.seek(by: -10) }
    @objc private func forward() { store.current?.seek(by: 10) }
}
