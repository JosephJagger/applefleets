import Foundation

struct BridgeConfiguration: Codable {
    var baseURL: URL
    var token: String
    var lastRenderedWorkoutID: UUID?
}

enum BridgeError: LocalizedError {
    case notPaired
    case invalidResponse
    case server(Int, String)

    var errorDescription: String? {
        switch self {
        case .notPaired: "Mac 尚未与 iPhone 配对，请先运行 applefleets pair。"
        case .invalidResponse: "iPhone 返回了无法识别的数据。"
        case .server(let status, let message): "iPhone 请求失败（\(status)）：\(message)"
        }
    }
}

final class ConfigurationStore {
    private let fileURL: URL

    init(baseDirectory: URL = FileManager.default.homeDirectoryForCurrentUser) {
        fileURL = baseDirectory.appendingPathComponent(".applefleets/config.json")
    }

    func load() throws -> BridgeConfiguration {
        guard let data = try? Data(contentsOf: fileURL) else { throw BridgeError.notPaired }
        return try JSONDecoder().decode(BridgeConfiguration.self, from: data)
    }

    func save(_ value: BridgeConfiguration) throws {
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(value).write(to: fileURL, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fileURL.path)
    }
}

struct BridgeClient {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func pair(baseURL: URL, code: String, deviceName: String = Host.current().localizedName ?? "Mac") async throws -> BridgeConfiguration {
        var request = URLRequest(url: baseURL.appendingPathComponent("pair"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["code": code, "device_name": deviceName])
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw BridgeError.invalidResponse }
        guard http.statusCode == 200 else {
            throw BridgeError.server(http.statusCode, String(data: data, encoding: .utf8) ?? "未知错误")
        }
        guard let body = try JSONSerialization.jsonObject(with: data) as? [String: String],
              let token = body["token"] else { throw BridgeError.invalidResponse }
        return BridgeConfiguration(baseURL: baseURL, token: token)
    }

    func latestRun(configuration: BridgeConfiguration) async throws -> RunSummary {
        var request = URLRequest(url: configuration.baseURL.appendingPathComponent("v1/latest-run"))
        request.setValue("Bearer \(configuration.token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 8
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw BridgeError.invalidResponse }
        guard http.statusCode == 200 else {
            throw BridgeError.server(http.statusCode, String(data: data, encoding: .utf8) ?? "未知错误")
        }
        do {
            return try JSONDecoder().decode(RunSummary.self, from: data)
        } catch {
            throw BridgeError.invalidResponse
        }
    }
}

