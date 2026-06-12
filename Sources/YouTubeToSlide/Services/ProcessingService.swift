import Foundation

struct ProcessingResult {
    var title: String
    var outputDirectory: URL
    var export: ExportResult
}

struct ProcessingCallbacks {
    var updateStatus: (JobStatus) -> Void
    var updateProgress: (Double) -> Void
    var updateTitleAndOutput: (String, URL) -> Void
}

struct ProcessingService {
    var tools: ToolStatus

    func process(
        job: ExtractionJob,
        settings: AppSettings,
        callbacks: ProcessingCallbacks
    ) async throws -> ProcessingResult {
        let temporaryRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("YouTubeToSlide-\(job.id.uuidString)", isDirectory: true)
        try? FileManager.default.removeItem(at: temporaryRoot)
        try FileManager.default.createDirectory(at: temporaryRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporaryRoot) }

        callbacks.updateStatus(.preparing)
        callbacks.updateProgress(0.03)

        var workingVideoURL: URL
        var title = job.title
        var outputDirectory = job.outputDirectory

        switch job.inputType {
        case .localVideo:
            guard let sourceURL = job.sourceURL else {
                throw CocoaError(.fileNoSuchFile)
            }
            workingVideoURL = sourceURL
        case .youtube:
            let downloader = YouTubeDownloadService(ytDlpPath: tools.ytDlpPath)
            let download = try downloader.download(url: job.source, into: temporaryRoot)
            workingVideoURL = download.videoURL
            title = download.title
            if job.usesAutomaticOutputDirectory {
                outputDirectory = OutputPathResolver.youtubeOutputDirectory(
                    title: title,
                    preferredRoot: settings.defaultOutputDirectory
                )
                callbacks.updateTitleAndOutput(title, outputDirectory)
            }
        }

        try validateWritableOutputDirectory(outputDirectory)

        callbacks.updateStatus(.extracting)
        callbacks.updateProgress(0.12)

        let extractor = FrameExtractionService(ffmpegPath: tools.ffmpegPath)
        let frames = try extractor.extractFrames(from: workingVideoURL, into: temporaryRoot, settings: settings)

        callbacks.updateStatus(.analyzing)

        let detector = SlideDetectionService()
        let candidates = try detector.detectSlides(from: frames, settings: settings) { analysisProgress in
            callbacks.updateProgress(0.2 + analysisProgress * 0.55)
        }

        callbacks.updateStatus(.exporting)
        callbacks.updateProgress(0.82)

        let exporter = ExportService()
        let export = try exporter.export(
            candidates: candidates,
            title: title,
            outputDirectory: outputDirectory,
            formats: settings.selectedFormats
        )

        callbacks.updateProgress(1.0)
        callbacks.updateStatus(.completed)

        return ProcessingResult(title: title, outputDirectory: outputDirectory, export: export)
    }

    private func validateWritableOutputDirectory(_ url: URL) throws {
        let parent = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)

        if FileManager.default.fileExists(atPath: url.path) {
            var isDirectory: ObjCBool = false
            if !FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) || !isDirectory.boolValue {
                throw CocoaError(.fileWriteFileExists)
            }
        } else {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }

        if !FileManager.default.isWritableFile(atPath: url.path) {
            throw CocoaError(.fileWriteNoPermission)
        }
    }
}
