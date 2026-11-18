import Foundation
import Observation
import AuthenticationServices
import AppKit
import CryptoKit
import Security

enum ServiceError: LocalizedError {
    case missingKey
    case notSignedIn
    case api(String)
    case auth(String)

    var errorDescription: String? {
        switch self {
        case .missingKey: return "API-Key fehlt. Trage ihn in den Einstellungen ein oder lege eine .env an."
        case .notSignedIn: return "Bitte zuerst mit Google anmelden."
        case .api(let m), .auth(let m): return m
        }
    }
}

// MARK: - API-Antworten

private struct Thumbs: Decodable {
    struct T: Decodable { let url: String }
    let medium: T?
    let high: T?
}

private struct Snippet: Decodable {
    struct Resource: Decodable { let videoId: String?; let channelId: String? }
    let title: String
    let channelTitle: String?
    let publishedAt: String?
    let thumbnails: Thumbs?
    let resourceId: Resource?

    private static let formatter = ISO8601DateFormatter()

    func video(id: String, short: Bool) -> Video {
        let thumb = (thumbnails?.high ?? thumbnails?.medium)?.url
        return Video(
            id: id,
            title: title,
            channel: channelTitle ?? "",
            thumbnail: thumb.flatMap { URL(string: $0) },
            published: publishedAt.flatMap { Self.formatter.date(from: $0) },
            isShort: short
        )
    }
}

private struct SearchResponse: Decodable {
    struct Item: Decodable {
        struct ID: Decodable { let videoId: String? }
        let id: ID
        let snippet: Snippet
    }
    let items: [Item]
}

private struct VideosResponse: Decodable {
    struct Item: Decodable { let id: String; let snippet: Snippet }
    let items: [Item]
}

private struct SnippetResponse: Decodable {
    struct Item: Decodable { let snippet: Snippet }
    let items: [Item]
}

private struct TokenResponse: Decodable {
    let access_token: String
    let expires_in: Int
    let refresh_token: String?
}

private struct APIErrorBody: Decodable {
    struct E: Decodable { let message: String }
    let error: E
}

/// Präsentiert die ASWebAuthenticationSession am aktuellen Fenster.
final class AuthAnchor: NSObject, ASWebAuthenticationPresentationContextProviding {
    nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        MainActor.assumeIsolated {
            NSApp.keyWindow ?? NSApp.windows.first ?? ASPresentationAnchor()
        }
    }
}

// MARK: - Service

@Observable
@MainActor
final class YouTubeService {
    static let shared = YouTubeService()
    static let loopbackPort: UInt16 = 53682

    var videos: [Video] = []
    var shorts: [Video] = []
    var subscriptions: [Video] = []
    var isLoading = false
    var errorMessage: String?
    var isSignedIn = false
    var credentials = CredentialStore.current()

    @ObservationIgnored private var accessToken: String?
    @ObservationIgnored private var refreshToken: String?
    @ObservationIgnored private var tokenExpiry = Date.distantPast
    @ObservationIgnored private var authSession: ASWebAuthenticationSession?
    @ObservationIgnored private let anchor = AuthAnchor()

    private init() {
        refreshToken = UserDefaults.standard.string(forKey: "refreshToken")
        isSignedIn = refreshToken != nil
    }

    func reloadCredentials() {
        credentials = CredentialStore.current()
    }

    // MARK: Daten laden

    func loadTrending() async {
        await run {
            let r: VideosResponse = try await self.get("videos", [
                "part": "snippet", "chart": "mostPopular", "regionCode": "DE", "maxResults": "25"
            ])
            self.videos = r.items.map { $0.snippet.video(id: $0.id, short: false) }
        }
    }

    func loadShorts() async {
        await search("", shorts: true)
    }

    func search(_ query: String, shorts isShorts: Bool) async {
        await run {
            var params = [
                "part": "snippet", "type": "video", "maxResults": "25", "regionCode": "DE",
                "q": query
            ]
            if isShorts {
                params["videoDuration"] = "short"
                params["q"] = (query + " #shorts").trimmingCharacters(in: .whitespaces)
                if query.isEmpty { params["order"] = "viewCount" }
            }
            let r: SearchResponse = try await self.get("search", params)
            let list = r.items.compactMap { item in
                item.id.videoId.map { item.snippet.video(id: $0, short: isShorts) }
            }
            if isShorts { self.shorts = list } else { self.videos = list }
        }
    }

    func loadSubscriptions() async {
        guard isSignedIn else { subscriptions = []; return }
        await run {
            let subs: SnippetResponse = try await self.get("subscriptions", [
                "part": "snippet", "mine": "true", "maxResults": "20", "order": "relevance"
            ], auth: true)
            let channelIDs = subs.items.compactMap { $0.snippet.resourceId?.channelId }
            let all = await withTaskGroup(of: [Video].self) { group in
                for id in channelIDs {
                    group.addTask { (try? await self.latestUploads(channelID: id)) ?? [] }
                }
                var out: [Video] = []
                for await part in group { out += part }
                return out
            }
            self.subscriptions = Array(all.sorted { ($0.published ?? .distantPast) > ($1.published ?? .distantPast) }.prefix(40))
        }
    }

    private func latestUploads(channelID: String) async throws -> [Video] {
        // Die Upload-Playlist eines Kanals hat die ID "UU" + Kanal-ID ohne "UC".
        let playlist = "UU" + String(channelID.dropFirst(2))
        let r: SnippetResponse = try await get("playlistItems", [
            "part": "snippet", "playlistId": playlist, "maxResults": "3"
        ], auth: true)
        return r.items.compactMap { item in
            item.snippet.resourceId?.videoId.map { item.snippet.video(id: $0, short: false) }
        }
    }

    /// Extrahiert eine Video-ID aus einem YouTube-Link.
    nonisolated static func videoID(from text: String) -> String? {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: t.hasPrefix("http") ? t : "https://" + t),
              let host = url.host?.lowercased() else { return nil }
        if host.contains("youtu.be") {
            let id = url.lastPathComponent
            return id.isEmpty || id == "/" ? nil : id
        }
        guard host.contains("youtube.com") else { return nil }
        if let v = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "v" })?.value {
            return v
        }
        let parts = url.pathComponents
        if parts.count >= 3, ["shorts", "embed", "live"].contains(parts[1]) { return parts[2] }
        return nil
    }

    // MARK: Netzwerk

    private func run(_ work: () async throws -> Void) async {
        isLoading = true
        errorMessage = nil
        do { try await work() } catch { errorMessage = error.localizedDescription }
        isLoading = false
    }

    private func get<T: Decodable>(_ path: String, _ query: [String: String], auth: Bool = false) async throws -> T {
        var items = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        if auth {
            try await ensureToken()
        } else {
            guard !credentials.apiKey.isEmpty else { throw ServiceError.missingKey }
            items.append(URLQueryItem(name: "key", value: credentials.apiKey))
        }
        var comps = URLComponents(string: "https://www.googleapis.com/youtube/v3/\(path)")!
        comps.queryItems = items
        var req = URLRequest(url: comps.url!)
        if auth, let t = accessToken { req.setValue("Bearer \(t)", forHTTPHeaderField: "Authorization") }
        let (data, resp) = try await URLSession.shared.data(for: req)
        if let http = resp as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            let msg = (try? JSONDecoder().decode(APIErrorBody.self, from: data))?.error.message
            throw ServiceError.api(msg ?? "HTTP \(http.statusCode)")
        }
        return try JSONDecoder().decode(T.self, from: data)
    }

    // MARK: OAuth

    func signIn() async {
        guard !credentials.clientID.isEmpty, !credentials.clientSecret.isEmpty else {
            errorMessage = "Client-ID/-Secret fehlen (Einstellungen oder .env)."
            return
        }
        do {
            let verifier = Self.randomToken(bytes: 48)
            let state = Self.randomToken(bytes: 16)
            let redirect = "http://127.0.0.1:\(Self.loopbackPort)"
            let challenge = Data(SHA256.hash(data: Data(verifier.utf8))).base64URL()

            var c = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
            c.queryItems = [
                URLQueryItem(name: "client_id", value: credentials.clientID),
                URLQueryItem(name: "redirect_uri", value: redirect),
                URLQueryItem(name: "response_type", value: "code"),
                URLQueryItem(name: "scope", value: "https://www.googleapis.com/auth/youtube.readonly"),
                URLQueryItem(name: "code_challenge", value: challenge),
                URLQueryItem(name: "code_challenge_method", value: "S256"),
                URLQueryItem(name: "state", value: state),
                URLQueryItem(name: "access_type", value: "offline"),
                URLQueryItem(name: "prompt", value: "consent")
            ]

            let params = try await authorize(url: c.url!)
            if let err = params["error"] { throw ServiceError.auth("Anmeldung abgebrochen (\(err)).") }
            guard params["state"] == state, let code = params["code"] else {
                throw ServiceError.auth("Ungültige Antwort von Google.")
            }

            let token = try await tokenRequest([
                "code": code,
                "client_id": credentials.clientID,
                "client_secret": credentials.clientSecret,
                "redirect_uri": redirect,
                "grant_type": "authorization_code",
                "code_verifier": verifier
            ])
            accessToken = token.access_token
            tokenExpiry = Date().addingTimeInterval(TimeInterval(token.expires_in))
            if let rt = token.refresh_token { refreshToken = rt }
            UserDefaults.standard.set(refreshToken, forKey: "refreshToken")
            isSignedIn = true
            errorMessage = nil
            await loadSubscriptions()
        } catch is CancellationError {
            return
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func signOut() {
        accessToken = nil
        refreshToken = nil
        tokenExpiry = .distantPast
        UserDefaults.standard.removeObject(forKey: "refreshToken")
        isSignedIn = false
        subscriptions = []
    }

    private func authorize(url: URL) async throws -> [String: String] {
        let server = LoopbackServer(port: Self.loopbackPort)
        try server.start()
        let session = ASWebAuthenticationSession(url: url, callbackURLScheme: "youtube-mini") { _, error in
            if let e = error as? ASWebAuthenticationSessionError, e.code == .canceledLogin {
                Task { @MainActor in server.cancel() }
            }
        }
        session.presentationContextProvider = anchor
        authSession = session
        defer {
            session.cancel()
            authSession = nil
            server.stop()
        }
        guard session.start() else { throw ServiceError.auth("Anmeldefenster konnte nicht geöffnet werden.") }
        return try await server.waitForCallback()
    }

    private func ensureToken() async throws {
        if accessToken != nil, tokenExpiry > Date().addingTimeInterval(60) { return }
        guard let rt = refreshToken else {
            isSignedIn = false
            throw ServiceError.notSignedIn
        }
        let r = try await tokenRequest([
            "client_id": credentials.clientID,
            "client_secret": credentials.clientSecret,
            "refresh_token": rt,
            "grant_type": "refresh_token"
        ])
        accessToken = r.access_token
        tokenExpiry = Date().addingTimeInterval(TimeInterval(r.expires_in))
    }

    private func tokenRequest(_ params: [String: String]) async throws -> TokenResponse {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._~"))
        var req = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.httpBody = params
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: allowed) ?? "")" }
            .joined(separator: "&")
            .data(using: .utf8)
        let (data, resp) = try await URLSession.shared.data(for: req)
        if let http = resp as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            let raw = String(data: data, encoding: .utf8) ?? "HTTP \(http.statusCode)"
            throw ServiceError.auth("Token-Fehler: \(raw)")
        }
        return try JSONDecoder().decode(TokenResponse.self, from: data)
    }

    private static func randomToken(bytes n: Int) -> String {
        var bytes = [UInt8](repeating: 0, count: n)
        _ = SecRandomCopyBytes(kSecRandomDefault, n, &bytes)
        return Data(bytes).base64URL()
    }
}

extension Data {
    func base64URL() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
