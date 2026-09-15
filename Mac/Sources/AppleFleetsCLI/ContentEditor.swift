import Foundation

struct EditorialPlan: Codable, Equatable, Sendable {
    let editor: String
    let theme: String
    let coverTitle: String
    let closingInsight: String
    let xiaohongshuTitle: String
    let xiaohongshuBody: String
    let xiaohongshuTags: [String]
    let douyinHook: String
    let douyinCaption: String
    let douyinTags: [String]

    static func fallback(for run: RunSummary) -> EditorialPlan {
        let insight: String
        if let first = run.splits.first?.duration,
           let last = run.splits.last?.duration,
           last < first - 5 {
            insight = "最后一公里比第一公里快了 \(Int(first - last)) 秒，后程比想象中更稳。"
        } else {
            insight = "今天没有追着数字跑，把节奏留在自己手里。"
        }
        let heart = run.averageHeartRate.map { "平均心率 \($0)，" } ?? ""
        return EditorialPlan(
            editor: "local-template",
            theme: "一次有据可查的跑步",
            coverTitle: "今天的跑步\n有据可查",
            closingInsight: insight,
            xiaohongshuTitle: "\(String(format: "%.2f", run.distanceKilometers)) 公里｜把今天跑成一张纸带",
            xiaohongshuBody: "用时 \(run.durationText)，平均配速 \(run.paceText)/km，\(heart)\(insight) 跑完再回头看，每一公里都有自己的脾气。",
            xiaohongshuTags: ["跑步打卡", "AppleWatch", "跑步日常", "配速记录", "运动生活"],
            douyinHook: "跑完以后，数字才开始说话",
            douyinCaption: "\(String(format: "%.2f", run.distanceKilometers)) 公里，用时 \(run.durationText)，平均配速 \(run.paceText)/km。\(insight)",
            douyinTags: ["跑步", "AppleWatch", "跑步记录", "运动日常"]
        )
    }
}

enum ContentEditor {
    static func edit(for run: RunSummary, in folder: URL, usingCodex: Bool) throws -> EditorialPlan {
        var plan = EditorialPlan.fallback(for: run)
        if usingCodex {
            print("[Codex] 正在分析配速、心率和分段，编辑两套平台内容…")
            do {
                plan = try runCodex(for: run, in: folder)
                print("[Codex] 编辑完成：\(plan.theme)")
            } catch {
                FileHandle.standardError.write(Data("[Codex] 编辑失败，改用本地模板：\(error.localizedDescription)\n".utf8))
            }
        } else {
            print("[本地模板] 未启用 Codex；使用固定内容方案。")
        }
        try writeArtifacts(plan, to: folder)
        return plan
    }

    private static func runCodex(for run: RunSummary, in folder: URL) throws -> EditorialPlan {
        let promptURL = folder.appendingPathComponent("codex-input.md")
        let outputURL = folder.appendingPathComponent("codex-output.json")
        let schemaURL = folder.appendingPathComponent("codex-output-schema.json")
        let prompt = prompt(for: run)
        try prompt.write(to: promptURL, atomically: true, encoding: .utf8)
        try schema.write(to: schemaURL, atomically: true, encoding: .utf8)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [
            "codex", "exec", "--ephemeral", "--skip-git-repo-check",
            "--sandbox", "read-only", "--output-schema", schemaURL.path,
            "--output-last-message", outputURL.path, "-"
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
        guard process.terminationStatus == 0 else { throw EditorError.codexExited(process.terminationStatus) }

        let response = try JSONDecoder().decode(CodexResponse.self, from: Data(contentsOf: outputURL))
        return EditorialPlan(
            editor: "codex",
            theme: response.theme,
            coverTitle: response.coverTitle,
            closingInsight: response.closingInsight,
            xiaohongshuTitle: response.xiaohongshuTitle,
            xiaohongshuBody: response.xiaohongshuBody,
            xiaohongshuTags: response.xiaohongshuTags,
            douyinHook: response.douyinHook,
            douyinCaption: response.douyinCaption,
            douyinTags: response.douyinTags
        )
    }

    private static func prompt(for run: RunSummary) -> String {
        """
        你是 AppleFleets 的中文跑步内容编辑。请根据训练摘要完成编辑，并返回符合给定 JSON Schema 的结果。

        1. 提炼一个真实、克制的内容主题。
        2. 写图卡双行封面标题和收尾洞察；coverTitle 可用换行符，最多两行。
        3. 分别写小红书标题、正文、话题，以及抖音前三秒钩子、短文案、话题。
        4. 从配速、心率或分段中寻找有依据的重点。不得虚构天气、地点、身体感受、目标或训练效果，不作医疗判断。
        5. 小红书标题不超过20个汉字，正文80到140字；抖音钩子不超过18个汉字。

        日期：\(run.startDate.formatted(date: .numeric, time: .omitted))
        距离：\(String(format: "%.2f", run.distanceKilometers)) km
        用时：\(run.durationText)
        平均配速：\(run.paceText)/km
        平均心率：\(run.averageHeartRate.map(String.init) ?? "无")
        最高心率：\(run.maximumHeartRate.map(String.init) ?? "无")
        每公里配速：\(run.splits.map { "\($0.kilometer)km \($0.paceText)" }.joined(separator: "，"))
        """
    }

    private static func writeArtifacts(_ plan: EditorialPlan, to folder: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        try encoder.encode(plan).write(to: folder.appendingPathComponent("content-plan.json"), options: .atomic)

        let xiaohongshu = """
        # \(plan.xiaohongshuTitle)

        \(plan.xiaohongshuBody)

        \(plan.xiaohongshuTags.map { "#\($0)" }.joined(separator: " "))
        """
        try xiaohongshu.write(to: folder.appendingPathComponent("xiaohongshu.md"), atomically: true, encoding: .utf8)

        let douyin = """
        # \(plan.douyinHook)

        \(plan.douyinCaption)

        \(plan.douyinTags.map { "#\($0)" }.joined(separator: " "))
        """
        try douyin.write(to: folder.appendingPathComponent("douyin.md"), atomically: true, encoding: .utf8)
    }

    private struct CodexResponse: Codable {
        let theme: String
        let coverTitle: String
        let closingInsight: String
        let xiaohongshuTitle: String
        let xiaohongshuBody: String
        let xiaohongshuTags: [String]
        let douyinHook: String
        let douyinCaption: String
        let douyinTags: [String]
    }

    private static let schema = """
    {"type":"object","additionalProperties":false,"properties":{"theme":{"type":"string"},"coverTitle":{"type":"string"},"closingInsight":{"type":"string"},"xiaohongshuTitle":{"type":"string"},"xiaohongshuBody":{"type":"string"},"xiaohongshuTags":{"type":"array","items":{"type":"string"}},"douyinHook":{"type":"string"},"douyinCaption":{"type":"string"},"douyinTags":{"type":"array","items":{"type":"string"}}},"required":["theme","coverTitle","closingInsight","xiaohongshuTitle","xiaohongshuBody","xiaohongshuTags","douyinHook","douyinCaption","douyinTags"]}
    """
}

private enum EditorError: LocalizedError {
    case codexExited(Int32)
    var errorDescription: String? {
        switch self { case .codexExited(let status): "Codex 退出码 \(status)" }
    }
}
