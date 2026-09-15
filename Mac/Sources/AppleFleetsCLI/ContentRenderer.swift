import Foundation
import SwiftRender

@MainActor
struct ContentRenderer {
    func render(_ run: RunSummary, plan: EditorialPlan, to folder: URL) async throws {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(run).write(to: folder.appendingPathComponent("workout.json"), options: .atomic)

        let postRecorder = Recorder(config: .init(
            fps: 30,
            size: CGSize(width: 1_080, height: 1_440),
            postFX: false
        ))
        for kind in RunCardKind.allCases {
            let output = folder.appendingPathComponent(String(format: "xiaohongshu-%02d.png", kind.rawValue + 1))
            try postRecorder.renderPNG(at: 1, to: output, postFX: false) { _ in
                RunCardView(run: run, plan: plan, kind: kind, verticalVideo: false)
            }
        }

        let videoRecorder = Recorder(config: .init(
            fps: 30,
            size: CGSize(width: 1_080, height: 1_920),
            bitrate: 10_000_000,
            postFX: false
        ))
        try await videoRecorder.render(
            to: folder.appendingPathComponent("douyin-vertical.mp4"),
            duration: 12,
            postFX: false
        ) { time in
            RunVideoView(run: run, plan: plan, time: time)
        }
    }
}
