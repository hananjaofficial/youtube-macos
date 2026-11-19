import SwiftUI
import Observation

/// Kennt den aktuellen Tab (des aktiven Fensters) und öffnet neue native Fenster-Tabs.
@Observable
@MainActor
final class TabStore {
    static let shared = TabStore()

    var current: BrowserTab?

    @ObservationIgnored private var pendingURL: URL?
    @ObservationIgnored private var timer: Timer?

    private init() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.current?.refreshPlayer() }
        }
    }

    /// Öffnet einen neuen nativen macOS-Tab (optional mit Adresse).
    func openNewTab(url: URL? = nil) {
        pendingURL = url
        NSApp.sendAction(#selector(NSWindow.newWindowForTab(_:)), to: nil, from: nil)
    }

    /// Startadresse für einen frisch erzeugten Tab.
    func takeStartURL() -> URL {
        defer { pendingURL = nil }
        return pendingURL ?? Service.youtube.home
    }

    func open(_ url: URL, inNewTab: Bool) {
        if inNewTab || current == nil {
            openNewTab(url: url)
        } else {
            current?.load(url)
        }
    }

    /// Suchtext oder Link aus dem Such-Overlay.
    func openInput(_ input: String) {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        if let url = Self.directURL(text) {
            current?.load(url)
        } else if let url = (current?.service ?? .youtube).searchURL(text) {
            current?.load(url)
        }
    }

    private static func directURL(_ text: String) -> URL? {
        if text.hasPrefix("http://") || text.hasPrefix("https://") { return URL(string: text) }
        let looksLikeLink = !text.contains(" ") && Service.allCases.contains { s in s.hosts.contains { text.contains($0) } }
        return looksLikeLink ? URL(string: "https://" + text) : nil
    }
}
