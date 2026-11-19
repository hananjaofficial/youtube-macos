import SwiftUI
import AppKit

@MainActor
struct ContentView: View {
    private let store = TabStore.shared
    @State private var showSearch = false
    @State private var query = ""
    @State private var pinned = false
    @State private var window: NSWindow?
    @FocusState private var searchFocused: Bool

    var body: some View {
        ZStack {
            VisualEffectView(material: .hudWindow).ignoresSafeArea()

            VStack(spacing: 8) {
                TabBar(store: store, showSearch: $showSearch, pinned: $pinned)
                ServiceCapsule(store: store)
                if showSearch {
                    searchField
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                if let tab = store.selected {
                    TabWebView(tab: tab)
                        .padding(.horizontal, 8)
                        .padding(.bottom, 8)
                }
            }
        }
        .ignoresSafeArea(.container, edges: .top)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: showSearch)
        .background(WindowAccessor { configure($0) })
        .onChange(of: pinned) { _, isPinned in
            window?.level = isPinned ? .floating : .normal
        }
        .onChange(of: showSearch) { _, visible in
            if visible { searchFocused = true }
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.secondary)
            TextField("Suchen oder Link einfügen", text: $query)
                .textFieldStyle(.plain)
                .focused($searchFocused)
                .onSubmit {
                    store.openInput(query)
                    query = ""
                    showSearch = false
                }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().stroke(.white.opacity(0.15), lineWidth: 1))
        .padding(.horizontal, 12)
        .onExitCommand { showSearch = false }
    }

    private func configure(_ w: NSWindow) {
        guard window !== w else { return }
        window = w
        w.applyGlass()
        TouchBarController.shared.attach(to: w)
    }
}
