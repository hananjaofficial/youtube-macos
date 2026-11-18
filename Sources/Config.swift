import Foundation

/// Zugangsdaten für die YouTube Data API und Google OAuth.
struct Credentials: Equatable {
    var apiKey = ""
    var clientID = ""
    var clientSecret = ""
}

/// Liest eine einfache `.env` (KEY=VALUE, Schlüssel nicht case-sensitiv).
enum Env {
    static func load() -> [String: String] {
        let fm = FileManager.default
        let candidates = [
            fm.currentDirectoryPath + "/.env",
            Bundle.main.bundleURL.deletingLastPathComponent().path + "/.env",
            NSHomeDirectory() + "/Library/Application Support/YouTube/.env",
            NSHomeDirectory() + "/website/Apps/YouTube/.env"
        ]
        for path in candidates {
            guard let text = try? String(contentsOfFile: path, encoding: .utf8) else { continue }
            var result: [String: String] = [:]
            for raw in text.split(whereSeparator: \.isNewline) {
                var line = raw.trimmingCharacters(in: .whitespaces)
                if line.isEmpty || line.hasPrefix("#") { continue }
                if line.hasPrefix("export ") { line.removeFirst(7) }
                guard let eq = line.firstIndex(of: "=") else { continue }
                let key = line[..<eq].trimmingCharacters(in: .whitespaces).lowercased()
                var value = line[line.index(after: eq)...].trimmingCharacters(in: .whitespaces)
                if value.count >= 2, let first = value.first, first == "\"" || first == "'", value.last == first {
                    value = String(value.dropFirst().dropLast())
                }
                result[key] = value
            }
            if !result.isEmpty { return result }
        }
        return [:]
    }
}

/// Reihenfolge: Einstellungen (UserDefaults) vor `.env`.
enum CredentialStore {
    private static let defaults = UserDefaults.standard

    static func current() -> Credentials {
        let env = Env.load()
        func pick(_ defaultsKey: String, _ envKeys: [String]) -> String {
            if let s = defaults.string(forKey: defaultsKey), !s.isEmpty { return s }
            for k in envKeys { if let v = env[k], !v.isEmpty { return v } }
            return ""
        }
        return Credentials(
            apiKey: pick("apiKey", ["key", "apikey", "api_key"]),
            clientID: pick("clientID", ["clientid", "client_id"]),
            clientSecret: pick("clientSecret", ["clientkey", "clientsecret", "client_secret"])
        )
    }

    static func save(_ c: Credentials) {
        defaults.set(c.apiKey, forKey: "apiKey")
        defaults.set(c.clientID, forKey: "clientID")
        defaults.set(c.clientSecret, forKey: "clientSecret")
    }
}
