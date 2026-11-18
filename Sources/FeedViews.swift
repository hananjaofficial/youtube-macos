import SwiftUI

/// Vorschaubild mit festem Seitenverhältnis (zugeschnitten).
struct Thumbnail: View {
    let url: URL?
    let ratio: CGFloat

    var body: some View {
        Color.clear
            .aspectRatio(ratio, contentMode: .fit)
            .overlay {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        Rectangle().fill(.quaternary)
                    }
                }
            }
            .clipped()
    }
}

struct VideoCard: View {
    let video: Video

    var body: some View {
        Button {
            PlayerController.shared.play(video)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                Thumbnail(url: video.thumbnail, ratio: 16 / 9)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    Text(video.title)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    HStack(spacing: 4) {
                        Text(video.channel).lineLimit(1)
                        if let date = video.published {
                            Text("·")
                            Text(date.formatted(.relative(presentation: .named)))
                        }
                    }
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 4)
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct VideoListView: View {
    let videos: [Video]

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(videos) { VideoCard(video: $0) }
            }
            .padding(12)
        }
        .scrollIndicators(.hidden)
    }
}

/// Vertikales 9:16-Feed mit seitenweisem Scrollen.
struct ShortsView: View {
    let shorts: [Video]

    var body: some View {
        GeometryReader { geo in
            ScrollView(.vertical) {
                LazyVStack(spacing: 0) {
                    ForEach(shorts) { short in
                        ShortCard(video: short)
                            .padding(12)
                            .frame(width: geo.size.width, height: geo.size.height)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollIndicators(.hidden)
        }
    }
}

struct ShortCard: View {
    let video: Video

    var body: some View {
        Button {
            PlayerController.shared.play(video)
        } label: {
            Thumbnail(url: video.thumbnail, ratio: 9 / 16)
                .overlay(alignment: .bottomLeading) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(video.title)
                            .font(.system(size: 14, weight: .semibold))
                            .lineLimit(3)
                        Text(video.channel)
                            .font(.system(size: 11))
                            .opacity(0.8)
                            .lineLimit(1)
                    }
                    .foregroundStyle(.white)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        LinearGradient(colors: [.clear, .black.opacity(0.65)], startPoint: .top, endPoint: .bottom)
                    )
                }
                .overlay {
                    Image(systemName: "play.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(.white)
                        .padding(18)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .shadow(color: .black.opacity(0.25), radius: 10, y: 4)
        }
        .buttonStyle(.plain)
    }
}

struct SubsView: View {
    let service: YouTubeService

    var body: some View {
        if service.isSignedIn {
            VideoListView(videos: service.subscriptions)
        } else {
            VStack(spacing: 12) {
                Image(systemName: "person.crop.circle.badge.checkmark")
                    .font(.system(size: 36))
                    .foregroundStyle(.secondary)
                Text("Melde dich mit Google an, um deine Abos zu sehen.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                Button("Mit Google anmelden") {
                    Task { await service.signIn() }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(30)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
