import Foundation

struct Video: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let channel: String
    let thumbnail: URL?
    let published: Date?
    var isShort = false
}

enum AppTab: String, CaseIterable, Identifiable {
    case videos = "Videos"
    case shorts = "Shorts"
    case subs = "Abos"

    var id: String { rawValue }
}
