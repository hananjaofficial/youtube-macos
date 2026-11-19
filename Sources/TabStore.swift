import SwiftUI
import Observation

/// Verwaltet alle Tabs (jeder Tab = eigene WebView).
@Observable
@MainActor
final class TabStore {
    static let shared = TabStore()

    var tabs: [BrowserTab] = []
    var selectedID: UUID?

    @ObservationIgnored private var timer: Timer?

    var selected: BrowserTab? { tabs.first { $0.id == selectedID } }

    private init() {
        newTab(url: Service.youtube.home)
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.selected?.refreshPlayer() }
        }
    }

    // MARK: - Tabs

    func newTab(url: URL) {
        let tab = BrowserTab(url: url, store: self)
        tabs.append(tab)
        select(tab)
    }

    func select(_ tab: BrowserTab) {
        guard selectedID != tab.id else { return }
        selected?.pause()   // inaktive Tabs spielen nicht weiter
        selectedID = tab.id
    }

    func close(_ tab: BrowserTab) {
        guard let index = tabs.firstIndex(where: { $0.id == tab.id }) else { return }
        let wasSelected = tab.id == selectedID
        tab.shutdown()
        tabs.remove(at: index)
        if tabs.isEmpty {
            newTab(url: Service.youtube.home)
        } else if wasSelected {
            selectedID = tabs[min(index, tabs.count - 1)].id
        }
    }

    func closeSelected() {
        if let tab = selected { close(tab) }
    }

    // MARK: - Öffnen

    func open(_ url: URL, inNewTab: Bool) {
        if inNewTab || selected == nil {
            newTab(url: url)
        } else {
            selected?.load(url)
        }
    }

    /// Suchtext oder Link aus dem Such-Overlay.
    func openInput(_ input: String) {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        if let url = Self.directURL(text) {
            open(url, inNewTab: false)
        } else if let url = (selected?.service ?? .youtube).searchURL(text) {
            open(url, inNewTab: false)
        }
    }

    private static func directURL(_ text: String) -> URL? {
        if text.hasPrefix("http://") || text.hasPrefix("https://") { return URL(string: text) }
        let looksLikeLink = !text.contains(" ") && Service.allCases.contains { s in s.hosts.contains { text.contains($0) } }
        return looksLikeLink ? URL(string: "https://" + text) : nil
    }
}
