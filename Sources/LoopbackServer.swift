import Foundation
import Network

/// Minimaler HTTP-Server auf 127.0.0.1, der den OAuth-Redirect von Google entgegennimmt.
@MainActor
final class LoopbackServer {
    private let port: NWEndpoint.Port
    private var listener: NWListener?
    private var continuation: CheckedContinuation<[String: String], Error>?
    private var pending: Result<[String: String], Error>?

    init(port: UInt16) {
        self.port = NWEndpoint.Port(rawValue: port)!
    }

    func start() throws {
        let params = NWParameters.tcp
        params.requiredInterfaceType = .loopback
        let l = try NWListener(using: params, on: port)
        l.newConnectionHandler = { [weak self] conn in
            Task { @MainActor in self?.handle(conn) }
        }
        l.start(queue: .main)
        listener = l
    }

    func stop() {
        listener?.cancel()
        listener = nil
    }

    func cancel() {
        deliver(.failure(CancellationError()))
    }

    func waitForCallback() async throws -> [String: String] {
        if let p = pending {
            pending = nil
            return try p.get()
        }
        return try await withCheckedThrowingContinuation { continuation = $0 }
    }

    private func deliver(_ result: Result<[String: String], Error>) {
        if let c = continuation {
            continuation = nil
            c.resume(with: result)
        } else if pending == nil {
            pending = result
        }
    }

    private func handle(_ conn: NWConnection) {
        conn.start(queue: .main)
        conn.receive(minimumIncompleteLength: 1, maximumLength: 8192) { [weak self] data, _, _, _ in
            let text = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
            let parts = text.components(separatedBy: " ")
            var params: [String: String] = [:]
            if parts.count > 1, let comps = URLComponents(string: "http://127.0.0.1" + parts[1]) {
                for item in comps.queryItems ?? [] { params[item.name] = item.value ?? "" }
            }
            let isCallback = params["code"] != nil || params["error"] != nil
            let body = isCallback
                ? "<html><head><meta charset=\"utf-8\"></head><body style=\"font-family:-apple-system;text-align:center;padding-top:60px\"><h2>Anmeldung abgeschlossen</h2><p>Du kannst dieses Fenster schließen.</p></body></html>"
                : "Not found"
            let status = isCallback ? "200 OK" : "404 Not Found"
            let response = "HTTP/1.1 \(status)\r\nContent-Type: text/html; charset=utf-8\r\nContent-Length: \(body.utf8.count)\r\nConnection: close\r\n\r\n\(body)"
            conn.send(content: response.data(using: .utf8), completion: .contentProcessed { _ in conn.cancel() })
            if isCallback {
                Task { @MainActor in self?.deliver(.success(params)) }
            }
        }
    }
}
