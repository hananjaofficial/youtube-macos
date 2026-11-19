import SwiftUI
import AppKit

/// Kapsel mit allen Diensten in einer Reihe: Logo + Abschnitts-Buttons je Dienst.
@MainActor
struct ServiceCapsule: View {
    let tab: BrowserTab

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Service.allCases) { service in
                group(service)
                if service != Service.allCases.last {
                    Divider().frame(height: 18)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().stroke(.white.opacity(0.15), lineWidth: 1))
    }

    private func group(_ service: Service) -> some View {
        let current = URL(string: tab.urlString)
        return HStack(spacing: 1) {
            Image(systemName: service.symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(service.tint)
                .frame(width: 22)
            ForEach(service.sections) { section in
                GlassButton(
                    symbol: section.symbol,
                    active: service.isActive(section, for: current),
                    help: "\(service.name) \(section.title)"
                ) {
                    // ⌘-Klick öffnet einen neuen Tab
                    if NSEvent.modifierFlags.contains(.command) {
                        TabStore.shared.openNewTab(url: section.url)
                    } else {
                        tab.load(section.url)
                    }
                }
            }
        }
    }
}
