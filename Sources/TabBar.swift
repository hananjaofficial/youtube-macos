import SwiftUI

/// Oberste Leiste: Tabs im Browser-Stil, Plus-Button und Teilen.
@MainActor
struct TabBar: View {
    let store: TabStore
    @Binding var showSearch: Bool
    @Binding var pinned: Bool

    var body: some View {
        HStack(spacing: 4) {
            Color.clear.frame(width: 70, height: 1)   // Platz für die Ampel-Buttons

            HStack(spacing: 4) {
                ForEach(store.tabs) { tab in
                    TabItem(tab: tab, selected: tab.id == store.selectedID, store: store)
                }
            }

            GlassButton(symbol: "plus", help: "Neuer Tab") {
                store.newTab(url: Service.youtube.home)
            }

            Spacer(minLength: 6)

            GlassButton(symbol: "magnifyingglass", active: showSearch, help: "Suchen") { showSearch.toggle() }
            GlassButton(symbol: "pip.enter", disabled: !(store.selected?.hasVideo ?? false), help: "Bild-im-Bild") {
                store.selected?.togglePiP()
            }
            GlassButton(symbol: pinned ? "pin.fill" : "pin", active: pinned, help: "Immer im Vordergrund") { pinned.toggle() }
            shareButton
        }
        .padding(.horizontal, 10)
        .frame(height: 38)
        .background(DragStrip())
    }

    @ViewBuilder
    private var shareButton: some View {
        if let text = store.selected?.urlString, !text.isEmpty, let url = URL(string: text) {
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

/// Ein einzelner Tab mit Dienst-Symbol, Seitentitel und Schließen-Knopf.
struct TabItem: View {
    let tab: BrowserTab
    let selected: Bool
    let store: TabStore
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: tab.service?.symbol ?? "globe")
                .font(.system(size: 11))
                .foregroundStyle(tab.service?.tint ?? Color.secondary)
            Text(tab.title)
                .font(.system(size: 12, weight: selected ? .semibold : .regular))
                .lineLimit(1)
            Spacer(minLength: 0)
            if selected || hovering {
                Button { store.close(tab) } label: {
                    Image(systemName: "xmark").font(.system(size: 9, weight: .bold))
                }
                .buttonStyle(.plain)
                .help("Tab schließen")
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 28)
        .frame(minWidth: 44, maxWidth: 160)
        .background(Capsule().fill(.white.opacity(selected ? 0.16 : (hovering ? 0.08 : 0))))
        .contentShape(Capsule())
        .onTapGesture { store.select(tab) }
        .onHover { hovering = $0 }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: selected)
    }
}
