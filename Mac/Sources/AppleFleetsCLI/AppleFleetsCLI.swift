import AppKit
import Foundation

@main
struct AppleFleetsCLI {
    static func main() async {
        do {
            try await run()
        } catch {
            FileHandle.standardError.write(Data("错误：\(error.localizedDescription)\n".utf8))
            exit(1)
        }
    }

    @MainActor
    private static func run() async throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        guard let command = arguments.first else {
            printUsage()
            return
        }
        let configStore = ConfigurationStore()
        let client = BridgeClient()

        switch command {
        case "pair":
            guard arguments.count == 3,
                  let url = URL(string: arguments[1]),
                  arguments[2].count == 6 else {
                throw UsageError("用法：applefleets pair http://iPhone地址:8765 六位配对码")
            }
            let config = try await client.pair(baseURL: url, code: arguments[2])
            try configStore.save(config)
            print("配对成功。")

        case "fetch":
            let run = try await client.latestRun(configuration: configStore.load())
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            print(String(data: try encoder.encode(run), encoding: .utf8) ?? "{}")

        case "demo":
            let folder = try outputFolder(for: .demo)
            try await createContent(for: .demo, folder: folder, useCodex: arguments.contains("--codex"))
            print("示例生成完成：\(folder.path)")
            NSWorkspace.shared.activateFileViewerSelecting([folder])

        case "render":
            var config = try configStore.load()
            let run = try await client.latestRun(configuration: config)
            let folder = try outputFolder(for: run)
            try await createContent(for: run, folder: folder, useCodex: arguments.contains("--codex"))
            config.lastRenderedWorkoutID = run.id
            try configStore.save(config)
            print("生成完成：\(folder.path)")
            NSWorkspace.shared.activateFileViewerSelecting([folder])

        case "watch":
            let useCodex = arguments.contains("--codex")
            let interval = parseInterval(arguments) ?? 60
            let inbox = RunInboxStore()
            let receiver = RunInboxServer(configurationStore: configStore, inbox: inbox)
            try receiver.start()
            print("正在监听新跑步，每 \(interval) 秒检查一次。按 Control-C 停止。")
            while !Task.isCancelled {
                do {
                    var config = try configStore.load()
                    let run: RunSummary
                    if let pushed = inbox.latest(), config.lastRenderedWorkoutID != pushed.id {
                        run = pushed
                    } else {
                        run = try await client.latestRun(configuration: config)
                    }
                    if config.lastRenderedWorkoutID != run.id {
                        let folder = try outputFolder(for: run)
                        try await createContent(for: run, folder: folder, useCodex: useCodex)
                        config.lastRenderedWorkoutID = run.id
                        try configStore.save(config)
                        print("新跑步已生成：\(folder.path)")
                    }
                } catch {
                    FileHandle.standardError.write(Data("等待 iPhone：\(error.localizedDescription)\n".utf8))
                }
                try await Task.sleep(for: .seconds(interval))
            }

        case "help", "--help", "-h":
            printUsage()
        default:
            throw UsageError("未知命令：\(command)")
        }
    }

    @MainActor
    private static func createContent(for run: RunSummary, folder: URL, useCodex: Bool) async throws {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let plan = try ContentEditor.edit(for: run, in: folder, usingCodex: useCodex)
        print("[渲染] 正在将 \(plan.editor) 编辑方案写入图卡和视频…")
        try await ContentRenderer().render(run, plan: plan, to: folder)
    }

    private static func outputFolder(for run: RunSummary) throws -> URL {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmm"
        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Movies/AppleFleets")
            .appendingPathComponent("\(formatter.string(from: run.startDate))-\(run.id.uuidString.prefix(8))")
    }

    private static func parseInterval(_ arguments: [String]) -> Int? {
        guard let index = arguments.firstIndex(of: "--interval"), arguments.indices.contains(index + 1) else { return nil }
        return Int(arguments[index + 1]).map { max(15, $0) }
    }

    private static func printUsage() {
        print("""
        AppleFleets — Apple Watch 跑步内容流水线

          applefleets pair <iPhone URL> <六位配对码>
          applefleets fetch
          applefleets demo [--codex]
          applefleets render [--codex]
          applefleets watch [--interval 60] [--codex]

        --codex 让 Codex 分析训练摘要，编辑选题、图卡标题、平台文案和话题。
        """)
    }
}

private struct UsageError: LocalizedError {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}
