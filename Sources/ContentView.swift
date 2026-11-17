import SwiftUI
import AppKit

struct ContentView: View {
    @ObservedObject private var player = PlayerController.shared
    @State private var input = ""
    @State private var pinned = false
    @State private var window: NSWindow?
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 0) {
            topBar
            WebViewContainer()
        }
        .ignoresSafeArea(.container, edges: .top)
        .background(WindowAccessor { configure($0) })
        .onChange(of: pinned) { _, isPinned in
            window?.level = isPinned ? .floating : .normal
        }
        .onChange(of: player.urlString) { _, newValue in
            if !focused { input = newValue }
        }
    }

    private var topBar: some View {
        HStack(spacing: 8) {
            // Platz für die Ampel-Buttons (Schließen/Minimieren/Zoom)
            Color.clear.frame(width: 62, height: 1)

            TextField("Suchen oder YouTube-Link einfügen", text: $input)
                .textFieldStyle(.roundedBorder)
                .focused($focused)
                .onSubmit {
                    player.load(input: input)
                    focused = false
                }

            Button {
                pinned.toggle()
            } label: {
                Image(systemName: pinned ? "pin.fill" : "pin")
                    .foregroundStyle(pinned ? Color.accentColor : Color.secondary)
            }
            .buttonStyle(.borderless)
            .help("Immer im Vordergrund")
        }
        .padding(.horizontal, 10)
        .frame(height: 38)
        .background(.ultraThinMaterial)
    }

    private func configure(_ w: NSWindow) {
        guard window !== w else { return }
        window = w
        w.titlebarAppearsTransparent = true
        w.titleVisibility = .hidden
        w.isMovableByWindowBackground = true
        TouchBarController.shared.attach(to: w)
    }
}

/// Liefert das NSWindow, in dem die SwiftUI-View steckt.
struct WindowAccessor: NSViewRepresentable {
    let onWindow: (NSWindow) -> Void

    func makeNSView(context: Context) -> NSView { NSView() }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            if let w = nsView.window { onWindow(w) }
        }
    }
}
