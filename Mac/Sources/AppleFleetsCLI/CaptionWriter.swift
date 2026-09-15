import Foundation

enum CaptionWriter {
    static func fallback(for run: RunSummary) -> String {
        let heart = run.averageHeartRate.map { "平均心率 \($0)，" } ?? ""
        let closing: String
        if let first = run.splits.first?.duration,
           let last = run.splits.last?.duration,
           last < first - 5 {
            closing = "最后一公里比第一公里快了 \(Int(first - last)) 秒，后程比想象中更稳。"
        } else {
            closing = "今天没有追着数字跑，把节奏留在自己手里。"
        }
        return """
        \(String(format: "%.2f", run.distanceKilometers)) 公里｜把今天跑成一张纸带

        用时 \(run.durationText)，平均配速 \(run.paceText)/km，\(heart)\(closing)

        跑完再回头看，每一公里都有自己的脾气。

        #跑步打卡 #AppleWatch #跑步日常 #配速记录 #运动生活
        """
    }

    static func write(for run: RunSummary, to output: URL, usingCodex: Bool) throws {
        let fallbackText = fallback(for: run)
        try fallbackText.write(to: output, atomically: true, encoding: .utf8)
        guard usingCodex else { return }

        let metrics = """
        日期：\(run.startDate.formatted(date: .numeric, time: .omitted))
        距离：\(String(format: "%.2f", run.distanceKilometers)) km
        用时：\(run.durationText)
        平均配速：\(run.paceText)/km
        平均心率：\(run.averageHeartRate.map(String.init) ?? "无")
        最高心率：\(run.maximumHeartRate.map(String.init) ?? "无")
        每公里配速：\(run.splits.map { "\($0.kilometer)km \($0.paceText)" }.joined(separator: "，"))
        """
        let prompt = """
        你是我的中文跑步内容编辑。根据下面准备公开的训练摘要，写一份自然、克制、有个人感的小红书和抖音通用文案。
        第一行是标题，不超过20个汉字。正文80到140字，不虚构天气、地点、感受或训练目标，不提供医疗判断。最后一行给5个相关话题。只输出可直接发布的成稿。

        \(metrics)
        """

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [
            "codex", "exec", "--ephemeral", "--skip-git-repo-check",
            "--sandbox", "read-only", "--output-last-message", output.path, "-"
        ]
        var environment = ProcessInfo.processInfo.environment
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let extraPaths = ["/opt/homebrew/bin", "/usr/local/bin", "\(home)/.local/bin"]
        environment["PATH"] = (extraPaths + [environment["PATH"] ?? "/usr/bin:/bin"]).joined(separator: ":")
        process.environment = environment
        let input = Pipe()
        process.standardInput = input
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.standardError
        try process.run()
        input.fileHandleForWriting.write(Data(prompt.utf8))
        try input.fileHandleForWriting.close()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            try fallbackText.write(to: output, atomically: true, encoding: .utf8)
            FileHandle.standardError.write(Data("Codex 文案步骤失败，已保留本地模板文案。\n".utf8))
            return
        }
    }
}
