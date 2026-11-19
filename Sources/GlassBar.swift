import SwiftUI

/// Runder Glas-Button (nur Symbol) mit Hover-Effekt und Symbol-Animation.
struct GlassButton: View {
    let symbol: String
    var active = false
    var disabled = false
    var compact = true
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
                .font(.system(size: compact ? 14 : 16, weight: .medium))
                .foregroundStyle(active ? Color.accentColor : Color.primary)
                .frame(width: compact ? 32 : 40, height: compact ? 28 : 36)
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
