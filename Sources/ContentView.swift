import SwiftUI
import AppKit

@MainActor
struct ContentView: View {
    private let service = YouTubeService.shared
    @ObservedObject private var player = PlayerController.shared
    @State private var tab: AppTab = .videos
    @State private var query = ""
    @State private var pinned = false
    @State private var showSettings = false
    @State private var window: NSWindow?

    var body: some View {
        ZStack {
            VisualEffectView(material: .hudWindow).ignoresSafeArea()

            VStack(spacing: 0) {
                header
                feed
            }

            if let video = player.current {
                PlayerView(video: video)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(1)
            }
        }
        .ignoresSafeArea(.container, edges: .top)
        .animation(.smooth(duration: 0.25), value: player.current?.id)
        .background(WindowAccessor { configure($0) })
        .task {
            await service.loadTrending()
            if service.isSignedIn { await service.loadSubscriptions() }
        }
        .onChange(of: tab) { _, newTab in load(newTab, onlyIfEmpty: true) }
        .onChange(of: pinned) { _, isPinned in
            window?.level = isPinned ? .floating : .normal
        }
    }

    // MARK: - Teile

    private var header: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                // Platz für die Ampel-Buttons
                Color.clear.frame(width: 62, height: 1)

                SearchField(text: $query) { submit() }
                    .frame(height: 24)

                Button {
                    pinned.toggle()
                } label: {
                    Image(systemName: pinned ? "pin.fill" : "pin")
                        .foregroundStyle(pinned ? Color.accentColor : Color.secondary)
                }
                .buttonStyle(.borderless)
                .help("Immer im Vordergrund")

                Button {
                    showSettings.toggle()
                } label: {
                    Image(systemName: "gearshape")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
                .help("Einstellungen")
                .popover(isPresented: $showSettings, arrowEdge: .bottom) {
                    SettingsView()
                }
            }

            Picker("", selection: $tab) {
                ForEach(AppTab.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
        .padding(.horizontal, 12)
        .padding(.top, 6)
        .padding(.bottom, 10)
        .background(VisualEffectView(material: .sidebar, blending: .withinWindow))
    }

    private var feed: some View {
        Group {
            switch tab {
            case .videos: VideoListView(videos: service.videos)
            case .shorts: ShortsView(shorts: service.shorts)
            case .subs: SubsView(service: service)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .top) {
            if service.isLoading {
                ProgressView()
                    .controlSize(.small)
                    .padding(8)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.top, 10)
            }
        }
        .overlay(alignment: .bottom) {
            if let message = service.errorMessage {
                Text(message)
                    .font(.system(size: 11))
                    .multilineTextAlignment(.leading)
                    .padding(10)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .padding(12)
                    .onTapGesture { service.errorMessage = nil }
            }
        }
    }

    // MARK: - Aktionen

    private func submit() {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if let id = YouTubeService.videoID(from: q) {
            let isShort = q.contains("/shorts/")
            player.play(Video(id: id, title: "", channel: "", thumbnail: nil, published: nil, isShort: isShort))
            return
        }
        if tab == .subs {
            tab = .videos   // löst load() über onChange aus
        } else {
            load(tab, onlyIfEmpty: false)
        }
    }

    private func load(_ t: AppTab, onlyIfEmpty: Bool) {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        Task {
            switch t {
            case .videos:
                if q.isEmpty {
                    if onlyIfEmpty && !service.videos.isEmpty { return }
                    await service.loadTrending()
                } else {
                    await service.search(q, shorts: false)
                }
            case .shorts:
                if q.isEmpty {
                    if onlyIfEmpty && !service.shorts.isEmpty { return }
                    await service.loadShorts()
                } else {
                    await service.search(q, shorts: true)
                }
            case .subs:
                await service.loadSubscriptions()
            }
        }
    }

    private func configure(_ w: NSWindow) {
        guard window !== w else { return }
        window = w
        w.titlebarAppearsTransparent = true
        w.titleVisibility = .hidden
        w.isOpaque = false
        w.backgroundColor = .clear
        w.isMovableByWindowBackground = true
        TouchBarController.shared.attach(to: w)
    }
}
