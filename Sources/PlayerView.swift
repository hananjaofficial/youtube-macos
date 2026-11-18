import SwiftUI

/// Rahmenloser Player-Container mit nativen Steuerelementen.
@MainActor
struct PlayerView: View {
    let video: Video
    @ObservedObject private var player = PlayerController.shared

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Button {
                    player.close()
                } label: {
                    Image(systemName: "chevron.down.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Schließen")

                Spacer()

                Button {
                    player.openInBrowser()
                } label: {
                    Image(systemName: "safari")
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Im Browser öffnen")
            }
            .padding(.top, 22)

            ZStack {
                WebViewContainer()
                    .aspectRatio(video.isShort ? 9.0 / 16.0 : 16.0 / 9.0, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                if let error = player.errorText {
                    Text(error)
                        .font(.system(size: 12))
                        .multilineTextAlignment(.center)
                        .padding(14)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .padding(20)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: 480)
            .shadow(color: .black.opacity(0.3), radius: 12, y: 6)

            VStack(spacing: 3) {
                Text(player.title.isEmpty ? video.title : player.title)
                    .font(.system(size: 14, weight: .semibold))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                if !video.channel.isEmpty {
                    Text(video.channel)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 26) {
                controlButton("gobackward.10") { player.seek(by: -10) }
                controlButton(player.isPlaying ? "pause.fill" : "play.fill", size: 26) { player.togglePlayPause() }
                controlButton("goforward.10") { player.seek(by: 10) }
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial, in: Capsule())

            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(VisualEffectView(material: .hudWindow, blending: .withinWindow).ignoresSafeArea())
    }

    private func controlButton(_ symbol: String, size: CGFloat = 20, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size))
                .frame(width: 34, height: 34)
        }
        .buttonStyle(.plain)
    }
}
