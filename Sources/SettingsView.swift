import SwiftUI

/// Popover für API-Key, Client-ID, Client-Secret und Google-Login.
@MainActor
struct SettingsView: View {
    private let service = YouTubeService.shared
    @State private var apiKey = ""
    @State private var clientID = ""
    @State private var clientSecret = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Einstellungen").font(.headline)

            field("API-Key") { SecureField("AIza…", text: $apiKey) }
            field("Client-ID") { TextField("….apps.googleusercontent.com", text: $clientID) }
            field("Client-Secret") { SecureField("GOCSPX-…", text: $clientSecret) }

            Text("Ohne Eingabe wird die .env verwendet (key, clientid, clientkey).")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Button("Speichern") { save() }
                Spacer()
                if service.isSignedIn {
                    Button("Abmelden") { service.signOut() }
                } else {
                    Button("Mit Google anmelden") {
                        save()
                        Task { await service.signIn() }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .textFieldStyle(.roundedBorder)
        .padding(16)
        .frame(width: 320)
        .onAppear {
            let c = service.credentials
            apiKey = c.apiKey
            clientID = c.clientID
            clientSecret = c.clientSecret
        }
    }

    private func field<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            content()
        }
    }

    private func save() {
        CredentialStore.save(Credentials(apiKey: apiKey, clientID: clientID, clientSecret: clientSecret))
        service.reloadCredentials()
    }
}
