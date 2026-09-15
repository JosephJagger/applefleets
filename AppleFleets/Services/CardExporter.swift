import SwiftUI
import UIKit

enum ExportFormat: Sendable {
    case post
    case story

    var pointSize: CGSize {
        switch self {
        case .post: CGSize(width: 360, height: 480)
        case .story: CGSize(width: 360, height: 640)
        }
    }

    var pixelSize: CGSize {
        switch self {
        case .post: CGSize(width: 1_080, height: 1_440)
        case .story: CGSize(width: 1_080, height: 1_920)
        }
    }
}

@MainActor
enum CardExporter {
    static func images(for run: WorkoutSummary, format: ExportFormat) throws -> [UIImage] {
        try CardKind.allCases.map { kind in
            let renderer = ImageRenderer(content: WorkoutCardView(run: run, kind: kind, format: format))
            renderer.scale = 3
            renderer.proposedSize = ProposedViewSize(format.pointSize)
            guard let image = renderer.uiImage else { throw ExportError.renderFailed }
            return image
        }
    }

    static func pngFiles(for run: WorkoutSummary) throws -> [URL] {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("AppleFleets-\(run.id.uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        return try images(for: run, format: .post).enumerated().map { index, image in
            let url = folder.appendingPathComponent(String(format: "run-card-%02d.png", index + 1))
            guard let data = image.pngData() else { throw ExportError.encodingFailed }
            try data.write(to: url, options: .atomic)
            return url
        }
    }
}

enum ExportError: LocalizedError {
    case renderFailed
    case encodingFailed
    case videoWriterFailed(String)

    var errorDescription: String? {
        switch self {
        case .renderFailed: "没有生成图片，请重试。"
        case .encodingFailed: "图片编码失败。"
        case .videoWriterFailed(let reason): "视频生成失败：\(reason)"
        }
    }
}

