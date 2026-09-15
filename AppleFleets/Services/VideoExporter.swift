import AVFoundation
import CoreGraphics
import UIKit

enum VideoExporter {
    static func export(images: [UIImage], id: UUID) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    continuation.resume(returning: try write(images: images, id: id))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private static func write(images: [UIImage], id: UUID) throws -> URL {
        guard !images.isEmpty else { throw ExportError.renderFailed }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("run-\(id.uuidString).mp4")
        try? FileManager.default.removeItem(at: url)

        let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        let settings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: 1_080,
            AVVideoHeightKey: 1_920,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: 8_000_000,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel
            ]
        ]
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        input.expectsMediaDataInRealTime = false
        let attributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
            kCVPixelBufferWidthKey as String: 1_080,
            kCVPixelBufferHeightKey as String: 1_920
        ]
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: attributes
        )
        guard writer.canAdd(input) else {
            throw ExportError.videoWriterFailed("当前设备不支持 H.264 编码")
        }
        writer.add(input)
        guard writer.startWriting() else {
            throw ExportError.videoWriterFailed(writer.error?.localizedDescription ?? "无法启动编码器")
        }
        writer.startSession(atSourceTime: .zero)

        let framesPerSecond: Int32 = 30
        let secondsPerCard = 3
        var frame: Int64 = 0

        for image in images {
            guard let cgImage = image.cgImage else { continue }
            for _ in 0..<(Int(framesPerSecond) * secondsPerCard) {
                while !input.isReadyForMoreMediaData { Thread.sleep(forTimeInterval: 0.003) }
                guard let pool = adaptor.pixelBufferPool else {
                    throw ExportError.videoWriterFailed("无法创建画面缓冲区")
                }
                var optionalBuffer: CVPixelBuffer?
                guard CVPixelBufferPoolCreatePixelBuffer(nil, pool, &optionalBuffer) == kCVReturnSuccess,
                      let buffer = optionalBuffer else {
                    throw ExportError.videoWriterFailed("无法写入画面")
                }
                draw(cgImage, into: buffer)
                let time = CMTime(value: frame, timescale: framesPerSecond)
                guard adaptor.append(buffer, withPresentationTime: time) else {
                    throw ExportError.videoWriterFailed(writer.error?.localizedDescription ?? "帧写入失败")
                }
                frame += 1
            }
        }

        input.markAsFinished()
        let semaphore = DispatchSemaphore(value: 0)
        writer.finishWriting { semaphore.signal() }
        semaphore.wait()
        guard writer.status == .completed else {
            throw ExportError.videoWriterFailed(writer.error?.localizedDescription ?? "编码未完成")
        }
        return url
    }

    private static func draw(_ image: CGImage, into buffer: CVPixelBuffer) {
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        guard let base = CVPixelBufferGetBaseAddress(buffer),
              let context = CGContext(
                data: base,
                width: 1_080,
                height: 1_920,
                bitsPerComponent: 8,
                bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
              ) else { return }
        context.translateBy(x: 0, y: 1_920)
        context.scaleBy(x: 1, y: -1)
        context.draw(image, in: CGRect(x: 0, y: 0, width: 1_080, height: 1_920))
    }
}

