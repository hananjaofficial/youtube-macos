import SwiftUI

/// Native Symbolleiste in der Titelzeile (anpassbar über „Symbolleiste anpassen…“).
@MainActor
struct BrowserToolbar: ToolbarContent {
    let tab: BrowserTab
    @Binding var showSearch: Bool
    @Binding var pinned: Bool

    var body: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            ServiceCapsule(tab: tab)
        }
        ToolbarItemGroup(placement: .primaryAction) {
            GlassButton(symbol: "magnifyingglass", active: showSearch, help: "Suchen") { showSearch.toggle() }
            GlassButton(symbol: "pip.enter", disabled: !tab.hasVideo, help: "Bild-im-Bild") { tab.togglePiP() }
            GlassButton(symbol: pinned ? "pin.fill" : "pin", active: pinned, help: "Immer im Vordergrund") { pinned.toggle() }
            shareButton
        }
    }

    @ViewBuilder
    private var shareButton: some View {
        if !tab.urlString.isEmpty, let url = URL(string: tab.urlString) {
            ShareLink(item: url) { shareIcon }
                .buttonStyle(.plain)
                .help("Teilen")
        } else {
            shareIcon.opacity(0.35)
        }
    }

    private var shareIcon: some View {
        Image(systemName: "square.and.arrow.up")
            .symbolRenderingMode(.hierarchical)
            .font(.system(size: 14, weight: .medium))
            .frame(width: 32, height: 28)
    }
}
