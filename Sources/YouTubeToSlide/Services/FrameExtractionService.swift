import Foundation

struct SampledFrame {
    var url: URL
    var timestampSec: Double
}

enum FrameExtractionError: LocalizedError {
    case missingFFmpeg
    case noFramesExtracted

    var errorDescription: String? {
        switch self {
        case .missingFFmpeg:
            return "ffmpeg is required for video processing. Install it with `brew install ffmpeg`."
        case .noFramesExtracted:
            return "No frames were extracted from the video."
        }
    }
}

struct FrameExtractionService {
    var ffmpegPath: String?

    func extractFrames(
        from videoURL: URL,
        into temporaryRoot: URL,
        settings: AppSettings
    ) throws -> [SampledFrame] {
        guard let ffmpegPath else {
            throw FrameExtractionError.missingFFmpeg
        }

        let frameDirectory = temporaryRoot.appendingPathComponent("sampled-frames", isDirectory: true)
        try FileManager.default.createDirectory(at: frameDirectory, withIntermediateDirectories: true)

        let fpsValue = 1.0 / max(settings.sampleInterval, 0.1)
        var filters = ["fps=fps=\(formatDecimal(fpsValue))"]

        if let scaleFilter = settings.resolution.ffmpegScaleFilter {
            filters.append(scaleFilter)
        } else if settings.resolution == .customWidth {
            filters.append("scale=\(max(settings.customWidth, 320)):-2")
        }

        let outputPattern = frameDirectory.appendingPathComponent("frame_%06d.png").path

        try ShellService.run(
            ffmpegPath,
            [
                "-hide_banner",
                "-loglevel", "error",
                "-y",
                "-i", videoURL.path,
                "-vf", filters.joined(separator: ","),
                "-vsync", "0",
                outputPattern
            ]
        )

        let frameURLs = try FileManager.default.contentsOfDirectory(
            at: frameDirectory,
            includingPropertiesForKeys: nil
        )
        .filter { $0.pathExtension.lowercased() == "png" }
        .sorted { $0.lastPathComponent < $1.lastPathComponent }

        guard !frameURLs.isEmpty else {
            throw FrameExtractionError.noFramesExtracted
        }

        return frameURLs.enumerated().map { index, url in
            SampledFrame(url: url, timestampSec: Double(index + 1) * settings.sampleInterval)
        }
    }

    private func formatDecimal(_ value: Double) -> String {
        String(format: "%.4f", value)
            .replacingOccurrences(of: #"0+$"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\.$"#, with: "", options: .regularExpression)
    }
}
