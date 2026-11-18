import SwiftUI

/// Runder Glas-Button mit Hover-Effekt und Symbol-Animation.
struct GlassButton: View {
    let symbol: String
    var active = false
    var disabled = false
    let help: String
    let action: () -> Void

    @State private var hovering = false
    @State private var taps = 0

    var body: some View {
        Button {
            taps += 1
            action()
        } label: {
            Image(systemName: symbol)
                .symbolRenderingMode(.hierarchical)
                .symbolEffect(.bounce, value: taps)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(active ? Color.accentColor : Color.primary)
                .frame(width: 40, height: 36)
                .background(Capsule().fill(.white.opacity(active ? 0.18 : (hovering ? 0.10 : 0))))
                .scaleEffect(hovering ? 1.06 : 1)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.35 : 1)
        .help(help)
        .onHover { hovering = $0 }
        .sensoryFeedback(.selection, trigger: taps)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: hovering)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: active)
    }
}

/// Schwebende, transluzente Navigationsleiste.
@MainActor
struct GlassBar: View {
    let engine: YouTubeEngine
    @Binding var showSearch: Bool
    @Binding var pinned: Bool

    var body: some View {
        HStack(spacing: 2) {
            GlassButton(symbol: "chevron.left", disabled: !engine.canGoBack, help: "Zurück") { engine.goBack() }
            GlassButton(symbol: "house.fill", active: engine.section == .home, help: "Start") { engine.goHome() }
            GlassButton(symbol: "play.square.stack.fill", active: engine.section == .shorts, help: "Shorts") { engine.goShorts() }
            GlassButton(symbol: "play.rectangle.on.rectangle.fill", active: engine.section == .subs, help: "Abos") { engine.goSubs() }
            GlassButton(symbol: "magnifyingglass", active: showSearch, help: "Suchen") { showSearch.toggle() }
            GlassButton(symbol: "pip.enter", disabled: !engine.hasVideo, help: "Bild-im-Bild") { engine.togglePiP() }
            GlassButton(symbol: pinned ? "pin.fill" : "pin", active: pinned, help: "Immer im Vordergrund") { pinned.toggle() }
        }
        .padding(6)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().stroke(.white.opacity(0.15), lineWidth: 1))
        .shadow(color: .black.opacity(0.25), radius: 14, y: 6)
    }
}
