import Foundation

struct WorkoutCopy: Equatable, Sendable {
    var title: String
    var body: String
    var hashtags: String

    static func make(for run: WorkoutSummary) -> WorkoutCopy {
        let closing: String
        if let last = run.splits.last?.duration,
           let first = run.splits.first?.duration,
           last < first - 5 {
            closing = "最后一公里比第一公里快了 \(Int(first - last)) 秒，今天的后程很稳。"
        } else {
            closing = "今天没有追着数字跑，把节奏留在自己手里。"
        }

        let heart = run.averageHeartRate.map { "平均心率 \($0)，" } ?? ""
        return WorkoutCopy(
            title: "\(String(format: "%.2f", run.distanceKilometers)) 公里｜把今天跑成一张纸带",
            body: "用时 \(run.durationText)，平均配速 \(run.paceText)/km，\(heart)\(closing)\n\n跑完再回头看，每一公里都有自己的脾气。",
            hashtags: "#跑步打卡 #AppleWatch #跑步日常 #配速记录 #运动生活"
        )
    }
}

