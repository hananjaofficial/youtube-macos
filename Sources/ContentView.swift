import SwiftUI
import AppKit

@MainActor
struct ContentView: View {
    private let engine = YouTubeEngine.shared
    @State private var showSearch = false
    @State private var query = ""
    @State private var pinned = false
    @State private var window: NSWindow?
    @FocusState private var searchFocused: Bool

    var body: some View {
        ZStack(alignment: .bottom) {
            VisualEffectView(material: .hudWindow).ignoresSafeArea()

            YouTubeWebView()

            // Ziehfläche oben (Titelleiste ist versteckt)
            VStack(spacing: 0) {
                DragStrip().frame(height: 30)
                Spacer(minLength: 0)
            }

            VStack(spacing: 10) {
                if showSearch {
                    searchField
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                GlassBar(engine: engine, showSearch: $showSearch, pinned: $pinned)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 14)
        }
        .ignoresSafeArea()
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
            TextField("Suchen oder YouTube-Link einfügen", text: $query)
                .textFieldStyle(.plain)
                .focused($searchFocused)
                .onSubmit {
                    engine.open(query)
                    query = ""
                    showSearch = false
                }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().stroke(.white.opacity(0.15), lineWidth: 1))
        .shadow(color: .black.opacity(0.25), radius: 14, y: 6)
        .onExitCommand { showSearch = false }
    }

    private func configure(_ w: NSWindow) {
        guard window !== w else { return }
        window = w
        w.applyGlass()
        TouchBarController.shared.attach(to: w)
    }
}
