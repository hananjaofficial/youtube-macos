import SwiftUI
import AppKit
import Combine

/// Erzeugt den Tab erst beim ersten Zugriff (nicht bei jedem View-Init).
@MainActor
final class TabBox {
    lazy var tab = BrowserTab(url: TabStore.shared.takeStartURL())
}

@MainActor
struct ContentView: View {
    private let store = TabStore.shared
    @State private var box = TabBox()
    @State private var showSearch = false
    @State private var query = ""
    @State private var pinned = false
    @State private var window: NSWindow?
    @FocusState private var searchFocused: Bool

    var body: some View {
        let tab = box.tab
        ZStack {
            VisualEffectView(material: .sidebar).ignoresSafeArea()

            VStack(spacing: 8) {
                if showSearch {
                    searchField
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                TabWebView(tab: tab)
                    .padding(.horizontal, 8)
                    .padding(.bottom, 8)
            }
        }
        .navigationTitle(tab.title)
        .toolbar { BrowserToolbar(tab: tab, showSearch: $showSearch, pinned: $pinned) }
        .toolbarBackground(.hidden, for: .windowToolbar)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: showSearch)
        .background(WindowAccessor { configure($0, tab: tab) })
        .onChange(of: pinned) { _, isPinned in
            window?.level = isPinned ? .floating : .normal
        }
        .onChange(of: showSearch) { _, visible in
            if visible { searchFocused = true }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { note in
            if let w = note.object as? NSWindow, w === window { store.current = tab }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.willCloseNotification)) { note in
            guard let w = note.object as? NSWindow, w === window else { return }
            tab.shutdown()
            if store.current === tab { store.current = nil }
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

    private func configure(_ w: NSWindow, tab: BrowserTab) {
        guard window !== w else { return }
        window = w
        w.applyGlass()
        w.tabbingIdentifier = "hanstePlayer"
        w.tabbingMode = .preferred
        // Neue Fenster werden als native Tabs ins bestehende Fenster eingefügt.
        if w.tabbedWindows == nil,
           let host = NSApp.windows.first(where: { $0 !== w && $0.tabbingIdentifier == "hanstePlayer" && $0.isVisible }) {
            host.addTabbedWindow(w, ordered: .above)
            w.makeKeyAndOrderFront(nil)
        }
        if w.isKeyWindow { store.current = tab }
        TouchBarController.shared.attach(to: w)
    }
}
