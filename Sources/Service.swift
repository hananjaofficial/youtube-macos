import SwiftUI

struct ServiceSection: Identifiable, Hashable {
    let id: String
    let title: String
    let symbol: String
    let url: URL
}

/// Unterstützte Dienste. Ein neuer Dienst = ein neuer Case mit Daten.
enum Service: String, CaseIterable, Identifiable {
    case youtube, instagram, tiktok

    var id: String { rawValue }

    var name: String {
        switch self {
        case .youtube: return "YouTube"
        case .instagram: return "Instagram"
        case .tiktok: return "TikTok"
        }
    }

    var symbol: String {
        switch self {
        case .youtube: return "play.rectangle.fill"
        case .instagram: return "camera.fill"
        case .tiktok: return "music.note"
        }
    }

    var tint: Color {
        switch self {
        case .youtube: return .red
        case .instagram: return Color(red: 0.88, green: 0.25, blue: 0.58)
        case .tiktok: return Color(red: 0.2, green: 0.85, blue: 0.9)
        }
    }

    var hosts: [String] {
        switch self {
        case .youtube: return ["youtube.com", "youtu.be"]
        case .instagram: return ["instagram.com"]
        case .tiktok: return ["tiktok.com"]
        }
    }

    var sections: [ServiceSection] {
        switch self {
        case .youtube:
            return [
                sec("start", "Start", "house.fill", "https://www.youtube.com/"),
                sec("shorts", "Shorts", "play.square.stack.fill", "https://www.youtube.com/shorts"),
                sec("subs", "Abos", "play.rectangle.on.rectangle.fill", "https://www.youtube.com/feed/subscriptions"),
                sec("me", "Meins", "person.crop.circle.fill", "https://www.youtube.com/feed/you")
            ]
        case .instagram:
            return [
                sec("start", "Start", "house.fill", "https://www.instagram.com/"),
                sec("reels", "Reels", "film.fill", "https://www.instagram.com/reels/"),
                sec("me", "Meins", "person.crop.circle.fill", "https://www.instagram.com/accounts/edit/")
            ]
        case .tiktok:
            return [
                sec("foryou", "Für dich", "sparkles", "https://www.tiktok.com/foryou"),
                sec("following", "Folge ich", "person.2.fill", "https://www.tiktok.com/following"),
                sec("me", "Meins", "person.crop.circle.fill", "https://www.tiktok.com/profile")
            ]
        }
    }

    var home: URL { sections[0].url }

    private func sec(_ key: String, _ title: String, _ symbol: String, _ url: String) -> ServiceSection {
        ServiceSection(id: "\(rawValue)-\(key)", title: title, symbol: symbol, url: URL(string: url)!)
    }

    func searchURL(_ query: String) -> URL? {
        let base: String
        let item: String
        switch self {
        case .youtube: base = "https://www.youtube.com/results"; item = "search_query"
        case .instagram: base = "https://www.instagram.com/explore/search/keyword/"; item = "q"
        case .tiktok: base = "https://www.tiktok.com/search"; item = "q"
        }
        var c = URLComponents(string: base)
        c?.queryItems = [URLQueryItem(name: item, value: query)]
        return c?.url
    }

    /// Ist der Abschnitt auf der aktuellen Adresse aktiv?
    func isActive(_ section: ServiceSection, for current: URL?) -> Bool {
        guard let current, Service.from(url: current) == self else { return false }
        let p = section.url.path
        if p.isEmpty || p == "/" { return current.path.isEmpty || current.path == "/" }
        return current.path.hasPrefix(p.hasSuffix("/") ? String(p.dropLast()) : p)
    }

    static func from(url: URL?) -> Service? {
        guard let host = url?.host?.lowercased() else { return nil }
        return allCases.first { s in s.hosts.contains { host == $0 || host.hasSuffix("." + $0) } }
    }

    /// Hosts, die in der App bleiben dürfen (inkl. Login-Weiterleitungen).
    static func isInternal(_ host: String?) -> Bool {
        guard let h = host?.lowercased() else { return false }
        let parts = ["youtube.", "youtu.be", "google.", "gstatic.", "instagram.", "facebook.", "fbcdn.", "cdninstagram.", "tiktok.", "tiktokv.", "tiktokcdn.", "byteoversea.", "ibytedtos."]
        return parts.contains { h.contains($0) }
    }
}
