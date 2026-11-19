import SwiftUI
import AppKit

/// Kapsel mit allen Diensten in einer Reihe: Logo + Abschnitts-Buttons je Dienst.
@MainActor
struct ServiceCapsule: View {
    let store: TabStore

    var body: some View {
        ViewThatFits(in: .horizontal) {
            content
            ScrollView(.horizontal, showsIndicators: false) { content }
        }
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().stroke(.white.opacity(0.15), lineWidth: 1))
        .shadow(color: .black.opacity(0.25), radius: 14, y: 6)
        .padding(.horizontal, 12)
    }

    private var content: some View {
        HStack(spacing: 6) {
            ForEach(Service.allCases) { service in
                group(service)
                if service != Service.allCases.last {
                    Divider().frame(height: 18)
                }
            }
        }
        .padding(6)
    }

    private func group(_ service: Service) -> some View {
        let current = URL(string: store.selected?.urlString ?? "")
        return HStack(spacing: 2) {
            Image(systemName: service.symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(service.tint)
                .frame(width: 24)
            ForEach(service.sections) { section in
                GlassButton(
                    symbol: section.symbol,
                    active: service.isActive(section, for: current),
                    help: "\(service.name) \(section.title)"
                ) {
                    // ⌘-Klick öffnet einen neuen Tab
                    store.open(section.url, inNewTab: NSEvent.modifierFlags.contains(.command))
                }
            }
        }
    }
}
