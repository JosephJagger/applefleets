import Foundation

struct HeartRatePoint: Codable, Hashable, Sendable {
    let secondsFromStart: TimeInterval
    let beatsPerMinute: Double
}

struct RunSplit: Codable, Hashable, Identifiable, Sendable {
    let kilometer: Int
    let duration: TimeInterval
    var id: Int { kilometer }
    var paceText: String { duration.paceText }
}

struct RunSummary: Codable, Hashable, Identifiable, Sendable {
    let id: UUID
    let startDate: Date
    let duration: TimeInterval
    let distanceMeters: Double
    let activeEnergyKcal: Double?
    let heartRate: [HeartRatePoint]
    let splits: [RunSplit]

    var distanceKilometers: Double { distanceMeters / 1_000 }
    var averagePace: TimeInterval { distanceKilometers > 0 ? duration / distanceKilometers : 0 }
    var averageHeartRate: Int? {
        guard !heartRate.isEmpty else { return nil }
        return Int((heartRate.map(\.beatsPerMinute).reduce(0, +) / Double(heartRate.count)).rounded())
    }
    var maximumHeartRate: Int? { heartRate.map(\.beatsPerMinute).max().map { Int($0.rounded()) } }
    var durationText: String { duration.clockText }
    var paceText: String { averagePace.paceText }

    static let demo = RunSummary(
        id: UUID(uuidString: "1267D33A-D075-4E36-BF8E-BE7FA3ED5B82")!,
        startDate: Date(timeIntervalSince1970: 1_780_000_000),
        duration: 3_126,
        distanceMeters: 10_240,
        activeEnergyKcal: 628,
        heartRate: stride(from: 0.0, through: 3_126.0, by: 75).map {
            HeartRatePoint(secondsFromStart: $0, beatsPerMinute: 139 + sin($0 / 270) * 12 + min($0 / 600, 8))
        },
        splits: [305, 301, 299, 307, 303, 296, 302, 309, 298, 294].enumerated().map {
            RunSplit(kilometer: $0.offset + 1, duration: TimeInterval($0.element))
        }
    )
}

extension TimeInterval {
    var paceText: String {
        guard isFinite, self > 0 else { return "--'--\"" }
        let total = Int(rounded())
        return String(format: "%d'%02d\"", total / 60, total % 60)
    }

    var clockText: String {
        let total = max(0, Int(rounded()))
        let hours = total / 3_600
        let minutes = (total % 3_600) / 60
        let seconds = total % 60
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, seconds)
            : String(format: "%02d:%02d", minutes, seconds)
    }
}

