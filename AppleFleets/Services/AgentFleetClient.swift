import Foundation
import Security
import Combine

struct GeneratedPlatformCopy: Codable, Equatable, Sendable {
    let title: String
    let body: String
    let hashtags: [String]
}

struct GeneratedCardCopy: Codable, Equatable, Sendable {
    let cover: String
    let closing: String
}

struct GeneratedContentPlan: Codable, Equatable, Sendable {
    let xiaohongshu: GeneratedPlatformCopy
    let douyin: GeneratedPlatformCopy
    let cards: GeneratedCardCopy
}

struct GeneratedMediaPackage: Sendable {
    let workoutID: UUID
    let images: [URL]
    let video: URL
}

@MainActor
final class AgentFleetClient: ObservableObject {
    enum State: Equatable {
        case notConfigured
        case ready
        case submitting
        case generating
        case rendering
        case completed
        case failed(String)
    }

    @Published var serverURL: String {
        didSet { UserDefaults.standard.set(serverURL, forKey: "agentfleet.serverURL") }
    }
    @Published var token: String {
        didSet { Self.saveToken(token) }
    }
    @Published private(set) var state: State
    @Published private(set) var media: GeneratedMediaPackage?

    private let session: URLSession
    private var activeTask: Task<GeneratedContentPlan, Error>?

    var isConfigured: Bool {
        guard let url = URL(string: serverURL), url.scheme == "https", url.host != nil else { return false }
        return token.count >= 32
    }

    init(session: URLSession = .shared) {
        let storedToken = Self.loadToken()
        let storedURL = UserDefaults.standard.string(forKey: "agentfleet.serverURL") ?? ""
        self.session = session
        serverURL = storedURL
        token = storedToken
        let url = URL(string: storedURL)
        state = storedToken.count >= 32 && url?.scheme == "https" && url?.host != nil ? .ready : .notConfigured
        media = nil
    }

    func refreshConfigurationState() {
        state = isConfigured ? .ready : .notConfigured
    }

    func generate(for workout: WorkoutSummary) async throws -> GeneratedContentPlan {
        if let activeTask { return try await activeTask.value }
        guard isConfigured else { throw AgentFleetError.notConfigured }
        let task = Task { [serverURL, token, session] in
            let baseURL = try Self.validatedBaseURL(serverURL)
            let requestID = "\(workout.id.uuidString.lowercased())-\(Int(workout.startDate.timeIntervalSince1970))"
            let creation = try await Self.createGeneration(baseURL: baseURL, token: token, requestID: requestID, workout: workout, session: session)
            await MainActor.run { self.state = .generating }
            UserDefaults.standard.set(creation.generationId, forKey: "agentfleet.pendingGenerationID")
            for _ in 0..<90 {
                let result = try await Self.readGeneration(baseURL: baseURL, token: token, id: creation.generationId, session: session)
                switch result.status {
                case "completed":
                    guard let plan = result.plan else { throw AgentFleetError.invalidResponse }
                    UserDefaults.standard.removeObject(forKey: "agentfleet.pendingGenerationID")
                    return plan
                case "failed":
                    throw AgentFleetError.remote(result.error?.message ?? "Linux 上的 Codex 没有完成生成。")
                default:
                    try await Task.sleep(for: .seconds(2))
                }
            }
            throw AgentFleetError.timedOut
        }
        activeTask = task
        state = .submitting
        do {
            let plan = try await task.value
            activeTask = nil
            state = .completed
            return plan
        } catch {
            activeTask = nil
            state = .failed(error.localizedDescription)
            throw error
        }
    }

    func renderMedia(for workout: WorkoutSummary, plan: GeneratedContentPlan) async throws {
        guard isConfigured else { throw AgentFleetError.notConfigured }
        state = .rendering
        do {
            let baseURL = try Self.validatedBaseURL(serverURL)
            let package = try await Self.createMedia(baseURL: baseURL, token: token, workout: workout, plan: plan, session: session)
            media = package
            state = .completed
        } catch {
            media = nil
            state = .failed("服务器媒体生成失败，仍可使用手机本地生成。\(error.localizedDescription)")
            throw error
        }
    }

    private struct Creation: Decodable { let generationId: String }
    private struct Failure: Decodable { let message: String }
    private struct Result: Decodable {
        let status: String
        let plan: GeneratedContentPlan?
        let error: Failure?
    }

    private struct WorkoutPayload: Encodable {
        struct Split: Encodable { let kilometer: Int; let durationSeconds: Double }
        let startedAt: Date
        let distanceKilometers: Double
        let durationSeconds: Double
        let averagePaceSeconds: Double
        let averageHeartRate: Int?
        let maximumHeartRate: Int?
        let activeEnergyKcal: Double?
        let splits: [Split]
    }

    private struct CreateBody: Encodable {
        let requestId: String
        let workout: WorkoutPayload
    }

    private struct RenderBody: Encodable {
        let id: String
        let workout: WorkoutPayload
        let plan: GeneratedContentPlan
    }

    private struct RenderManifest: Decodable {
        struct Xiaohongshu: Decodable {
            let images: [URL]
            let title: String
            let body: String
            let hashtags: [String]
        }
        struct Douyin: Decodable {
            let video: URL
            let title: String
            let body: String
            let hashtags: [String]
        }
        let id: String
        let xiaohongshu: Xiaohongshu
        let douyin: Douyin
    }

    private static func createGeneration(baseURL: URL, token: String, requestID: String, workout: WorkoutSummary, session: URLSession) async throws -> Creation {
        let payload = WorkoutPayload(
            startedAt: workout.startDate,
            distanceKilometers: workout.distanceKilometers,
            durationSeconds: workout.duration,
            averagePaceSeconds: workout.averagePace,
            averageHeartRate: workout.averageHeartRate,
            maximumHeartRate: workout.maximumHeartRate,
            activeEnergyKcal: workout.activeEnergyKcal,
            splits: workout.splits.map { .init(kilometer: $0.kilometer, durationSeconds: $0.duration) }
        )
        var request = URLRequest(url: baseURL.appending(path: "api/integrations/applefleets/generations"))
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        request.httpBody = try encoder.encode(CreateBody(requestId: requestID, workout: payload))
        return try await send(request, as: Creation.self, session: session)
    }

    private static func readGeneration(baseURL: URL, token: String, id: String, session: URLSession) async throws -> Result {
        var request = URLRequest(url: baseURL.appending(path: "api/integrations/applefleets/generations/\(id)"))
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return try await send(request, as: Result.self, session: session)
    }

    private static func createMedia(baseURL: URL, token: String, workout: WorkoutSummary, plan: GeneratedContentPlan, session: URLSession) async throws -> GeneratedMediaPackage {
        let payload = WorkoutPayload(
            startedAt: workout.startDate,
            distanceKilometers: workout.distanceKilometers,
            durationSeconds: workout.duration,
            averagePaceSeconds: workout.averagePace,
            averageHeartRate: workout.averageHeartRate,
            maximumHeartRate: workout.maximumHeartRate,
            activeEnergyKcal: workout.activeEnergyKcal,
            splits: workout.splits.map { .init(kilometer: $0.kilometer, durationSeconds: $0.duration) }
        )
        let renderID = "run_\(workout.id.uuidString.lowercased().replacingOccurrences(of: "-", with: ""))"
        var request = URLRequest(url: baseURL.appending(path: "iwatch-api/renders"))
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 120
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        request.httpBody = try encoder.encode(RenderBody(id: renderID, workout: payload, plan: plan))
        let manifest = try await send(request, as: RenderManifest.self, session: session)
        let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("GeneratedMedia/\(renderID)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let images = try await download(manifest.xiaohongshu.images, token: token, to: folder, session: session)
        let videos = try await download([manifest.douyin.video], token: token, to: folder, session: session)
        guard let video = videos.first else { throw AgentFleetError.invalidResponse }
        return GeneratedMediaPackage(workoutID: workout.id, images: images, video: video)
    }

    private static func download(_ urls: [URL], token: String, to folder: URL, session: URLSession) async throws -> [URL] {
        var files: [URL] = []
        for remoteURL in urls {
            var request = URLRequest(url: remoteURL)
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.timeoutInterval = 120
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else { throw AgentFleetError.invalidResponse }
            let destination = folder.appendingPathComponent(remoteURL.lastPathComponent)
            try data.write(to: destination, options: .atomic)
            files.append(destination)
        }
        return files
    }

    private static func send<T: Decodable>(_ request: URLRequest, as type: T.Type, session: URLSession) async throws -> T {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw AgentFleetError.invalidResponse }
        guard 200..<300 ~= http.statusCode else {
            let envelope = try? JSONDecoder().decode(ErrorEnvelope.self, from: data)
            throw AgentFleetError.remote(envelope?.error.message ?? "AgentFleet 返回错误（\(http.statusCode)）。")
        }
        do { return try JSONDecoder().decode(T.self, from: data) }
        catch { throw AgentFleetError.invalidResponse }
    }

    private struct ErrorEnvelope: Decodable { let error: Failure }

    private static func validatedBaseURL(_ value: String) throws -> URL {
        guard var components = URLComponents(string: value.trimmingCharacters(in: .whitespacesAndNewlines)),
              components.scheme == "https", components.host != nil else { throw AgentFleetError.invalidURL }
        components.path = ""
        components.query = nil
        components.fragment = nil
        guard let url = components.url else { throw AgentFleetError.invalidURL }
        return url
    }

    private static let keychainService = "com.local.applefleets.agentfleet"
    private static let keychainAccount = "api-token"

    private static func saveToken(_ token: String) {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: keychainService, kSecAttrAccount as String: keychainAccount]
        SecItemDelete(query as CFDictionary)
        guard !token.isEmpty, let data = token.data(using: .utf8) else { return }
        var item = query
        item[kSecValueData as String] = data
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(item as CFDictionary, nil)
    }

    private static func loadToken() -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return "" }
        return String(data: data, encoding: .utf8) ?? ""
    }
}

enum AgentFleetError: LocalizedError {
    case notConfigured
    case invalidURL
    case invalidResponse
    case timedOut
    case remote(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured: "请先填写 AgentFleet 地址和连接令牌。"
        case .invalidURL: "AgentFleet 地址必须是有效的 HTTPS 地址。"
        case .invalidResponse: "AgentFleet 返回的数据无法读取。"
        case .timedOut: "Codex 仍在生成，请稍后重新打开 App 查看。"
        case .remote(let message): message
        }
    }
}
