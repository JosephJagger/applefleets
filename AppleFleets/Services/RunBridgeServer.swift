// Local bridge architecture adapted from rakshith48/healthkit-cli (MIT).
import Foundation
import Combine
import Network
import Swifter
import UIKit

private final class WorkoutSnapshot: @unchecked Sendable {
    private let lock = NSLock()
    private var data: Data?

    func set(_ workout: WorkoutSummary) {
        let encoded = try? JSONEncoder().encode(workout)
        lock.lock()
        data = encoded
        lock.unlock()
    }

    func get() -> Data? {
        lock.lock()
        defer { lock.unlock() }
        return data
    }
}

@MainActor
final class RunBridgeServer: ObservableObject {
    @Published private(set) var isRunning = false
    @Published private(set) var address = ""
    let auth = BridgeAuthStore()

    private let port: UInt16 = 8765
    private let server = HttpServer()
    private let snapshot = WorkoutSnapshot()
    private var advertiser: NWListener?
    private var authObservation: AnyCancellable?

    init() {
        authObservation = auth.objectWillChange.sink { [weak self] in
            self?.objectWillChange.send()
        }
    }

    func publish(_ workout: WorkoutSummary) {
        snapshot.set(workout)
        pushToPairedMacs(workout)
    }

    func start() {
        guard !isRunning else { return }
        registerRoutes()
        do {
            try server.start(port, forceIPv4: true)
            address = localIPv4().map { "http://\($0):\(port)" } ?? "端口 \(port)"
            isRunning = true
            advertise()
        } catch {
            address = "启动失败：\(error.localizedDescription)"
        }
    }

    private func registerRoutes() {
        let auth = auth
        let snapshot = snapshot

        server.POST["/pair"] = { request in
            let body = Data(request.body.map { UInt8($0) })
            guard let object = try? JSONSerialization.jsonObject(with: body) as? [String: String],
                  let code = object["code"],
                  let name = object["device_name"] else {
                return Self.json(["error": "invalid_request"], status: 400)
            }
            var token: String?
            let host = request.address ?? ""
            DispatchQueue.main.sync {
                token = auth.consume(code: code, macName: String(name.prefix(80)), host: host)
            }
            guard let token else { return Self.json(["error": "invalid_pairing_code"], status: 403) }
            return Self.json(["token": token])
        }

        server.GET["/v1/latest-run"] = { request in
            guard Self.bearerToken(from: request).map(auth.validates) == true else {
                return Self.json(["error": "unauthorized"], status: 401)
            }
            guard let data = snapshot.get() else {
                return Self.json(["error": "no_running_workout"], status: 404)
            }
            return .raw(200, "OK", ["Content-Type": "application/json"]) { writer in
                try writer.write(data)
            }
        }

        server.GET["/status"] = { request in
            guard Self.bearerToken(from: request).map(auth.validates) == true else {
                return Self.json(["error": "unauthorized"], status: 401)
            }
            return Self.json([
                "online": "true",
                "device": UIDevice.current.name,
                "has_workout": snapshot.get() == nil ? "false" : "true"
            ])
        }
    }

    private func pushToPairedMacs(_ workout: WorkoutSummary) {
        guard let body = try? JSONEncoder().encode(workout) else { return }
        for mac in auth.destinations() where !mac.host.isEmpty {
            Task {
                guard let url = URL(string: "http://\(mac.host):8766/v1/run") else { return }
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.timeoutInterval = 8
                request.httpBody = body
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.setValue("Bearer \(mac.id)", forHTTPHeaderField: "Authorization")
                _ = try? await URLSession.shared.data(for: request)
            }
        }
    }

    private func advertise() {
        do {
            let listener = try NWListener(using: .tcp)
            listener.service = NWListener.Service(
                name: "AppleFleets iPhone",
                type: "_applefleets._tcp",
                txtRecord: NWTXTRecord(["port": "\(port)"])
            )
            listener.newConnectionHandler = { $0.cancel() }
            listener.start(queue: .global(qos: .utility))
            advertiser = listener
        } catch {
            // Manual pairing with the displayed IP address still works.
        }
    }

    private nonisolated static func bearerToken(from request: HttpRequest) -> String? {
        guard let header = request.headers.first(where: { $0.0.lowercased() == "authorization" })?.1,
              header.lowercased().hasPrefix("bearer ") else { return nil }
        return String(header.dropFirst(7))
    }

    private nonisolated static func json(_ body: [String: String], status: Int = 200) -> HttpResponse {
        guard let data = try? JSONEncoder().encode(body) else { return .internalServerError }
        return .raw(status, status == 200 ? "OK" : "Error", ["Content-Type": "application/json"]) {
            try $0.write(data)
        }
    }

    private func localIPv4() -> String? {
        var result: String?
        var interfaces: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&interfaces) == 0, let first = interfaces else { return nil }
        defer { freeifaddrs(interfaces) }

        for pointer in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let interface = pointer.pointee
            guard interface.ifa_addr.pointee.sa_family == UInt8(AF_INET),
                  String(cString: interface.ifa_name) == "en0" else { continue }
            var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            getnameinfo(
                interface.ifa_addr,
                socklen_t(interface.ifa_addr.pointee.sa_len),
                &host,
                socklen_t(host.count),
                nil,
                0,
                NI_NUMERICHOST
            )
            result = String(cString: host)
        }
        return result
    }
}
