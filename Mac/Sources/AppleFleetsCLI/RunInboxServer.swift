import Foundation
import Network

final class RunInboxStore: @unchecked Sendable {
    private let fileURL: URL
    private let lock = NSLock()

    init(baseDirectory: URL = FileManager.default.homeDirectoryForCurrentUser) {
        fileURL = baseDirectory.appendingPathComponent(".applefleets/inbox/latest-run.json")
    }

    func save(_ data: Data) throws {
        _ = try JSONDecoder().decode(RunSummary.self, from: data)
        lock.lock()
        defer { lock.unlock() }
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: fileURL, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fileURL.path)
    }

    func latest() -> RunSummary? {
        lock.lock()
        defer { lock.unlock() }
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder().decode(RunSummary.self, from: data)
    }
}

final class RunInboxServer: @unchecked Sendable {
    private let configurationStore: ConfigurationStore
    private let inbox: RunInboxStore
    private var listener: NWListener?

    init(configurationStore: ConfigurationStore, inbox: RunInboxStore) {
        self.configurationStore = configurationStore
        self.inbox = inbox
    }

    func start() throws {
        let listener = try NWListener(using: .tcp, on: 8766)
        listener.service = NWListener.Service(name: "AppleFleets Mac", type: "_applefleets-mac._tcp")
        listener.newConnectionHandler = { [weak self] connection in self?.accept(connection) }
        listener.start(queue: .global(qos: .utility))
        self.listener = listener
    }

    private func accept(_ connection: NWConnection) {
        connection.start(queue: .global(qos: .utility))
        receive(connection, accumulated: Data())
    }

    private func receive(_ connection: NWConnection, accumulated: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { [weak self] chunk, _, complete, error in
            guard let self else { return }
            var data = accumulated
            if let chunk { data.append(chunk) }
            if data.count > 5_000_000 {
                self.respond(connection, status: 413, message: "payload_too_large")
            } else if let request = self.parseCompleteRequest(data) {
                self.handle(request, connection: connection)
            } else if complete || error != nil {
                self.respond(connection, status: 400, message: "invalid_request")
            } else {
                self.receive(connection, accumulated: data)
            }
        }
    }

    private struct Request {
        let method: String
        let path: String
        let headers: [String: String]
        let body: Data
    }

    private func parseCompleteRequest(_ data: Data) -> Request? {
        let separator = Data("\r\n\r\n".utf8)
        guard let headerRange = data.range(of: separator),
              let headerText = String(data: data[..<headerRange.lowerBound], encoding: .utf8) else { return nil }
        let lines = headerText.components(separatedBy: "\r\n")
        let requestLine = lines.first?.split(separator: " ") ?? []
        guard requestLine.count >= 2 else { return nil }
        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            let pair = line.split(separator: ":", maxSplits: 1).map(String.init)
            if pair.count == 2 {
                headers[pair[0].lowercased()] = pair[1].trimmingCharacters(in: .whitespaces)
            }
        }
        let length = Int(headers["content-length"] ?? "0") ?? 0
        let bodyStart = headerRange.upperBound
        guard data.count >= bodyStart + length else { return nil }
        return Request(
            method: String(requestLine[0]),
            path: String(requestLine[1]),
            headers: headers,
            body: data.subdata(in: bodyStart..<(bodyStart + length))
        )
    }

    private func handle(_ request: Request, connection: NWConnection) {
        guard request.method == "POST", request.path == "/v1/run" else {
            respond(connection, status: 404, message: "not_found")
            return
        }
        guard let config = try? configurationStore.load(),
              request.headers["authorization"] == "Bearer \(config.token)" else {
            respond(connection, status: 401, message: "unauthorized")
            return
        }
        do {
            try inbox.save(request.body)
            respond(connection, status: 200, message: "accepted")
        } catch {
            respond(connection, status: 422, message: "invalid_workout")
        }
    }

    private func respond(_ connection: NWConnection, status: Int, message: String) {
        let body = Data("{\"status\":\"\(message)\"}".utf8)
        let reason = status == 200 ? "OK" : "Error"
        let header = "HTTP/1.1 \(status) \(reason)\r\nContent-Type: application/json\r\nContent-Length: \(body.count)\r\nConnection: close\r\n\r\n"
        connection.send(content: Data(header.utf8) + body, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }
}

