import AppKit
import Foundation

@MainActor
final class JobStore: ObservableObject {
    @Published var jobs: [ExtractionJob] = []
    @Published var selectedJobID: UUID?
    @Published var settings: AppSettings
    @Published var toolStatus: ToolStatus
    @Published var isProcessing = false
    @Published var installingFormula: String?
    @Published var message: String?

    private var processingTask: Task<Void, Never>?
    private let supportedVideoExtensions: Set<String> = [
        "mp4", "mov", "m4v", "avi", "mkv", "webm", "wmv", "flv", "mpg", "mpeg"
    ]

    init() {
        var initialSettings = AppSettings()
        if let storedPath = UserDefaults.standard.string(forKey: "defaultOutputDirectory") {
            initialSettings.defaultOutputDirectory = URL(fileURLWithPath: storedPath)
        }
        self.settings = initialSettings
        self.toolStatus = ToolResolver.resolve()
    }

    var selectedJob: ExtractionJob? {
        guard let selectedJobID else {
            return jobs.first
        }
        return jobs.first(where: { $0.id == selectedJobID })
    }

    func refreshTools() {
        toolStatus = ToolResolver.resolve()
    }

    func addLocalVideos(_ urls: [URL]) {
        let videoURLs = urls.filter { supportedVideoExtensions.contains($0.pathExtension.lowercased()) }

        guard !videoURLs.isEmpty else {
            message = "Drop a supported video file: mp4, mov, m4v, avi, mkv, webm."
            return
        }

        for url in videoURLs {
            let title = FileNameSanitizer.sanitize(url.deletingPathExtension().lastPathComponent)
            let outputDirectory = deduplicatedOutputDirectory(OutputPathResolver.localOutputDirectory(for: url))
            let job = ExtractionJob(
                inputType: .localVideo,
                source: url.path,
                sourceURL: url,
                title: title,
                outputDirectory: outputDirectory
            )
            jobs.append(job)
            selectedJobID = job.id
        }
    }

    func addYouTubeURL(_ rawURL: String, preview: YouTubePreview? = nil) {
        let trimmed = rawURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return
        }

        guard trimmed.lowercased().hasPrefix("http://") || trimmed.lowercased().hasPrefix("https://") else {
            message = "Enter a full YouTube URL beginning with http:// or https://."
            return
        }

        let title = preview?.title ?? "YouTube Video"
        let outputDirectory = deduplicatedOutputDirectory(
            OutputPathResolver.youtubeOutputDirectory(title: title, preferredRoot: settings.defaultOutputDirectory)
        )
        let job = ExtractionJob(
            inputType: .youtube,
            source: trimmed,
            title: title,
            outputDirectory: outputDirectory,
            youtubePreview: preview
        )
        jobs.append(job)
        selectedJobID = job.id
    }

    func installYtDlp() {
        installFormula("yt-dlp")
    }

    func installFFmpeg() {
        installFormula("ffmpeg")
    }

    func removeSelectedJob() {
        guard let selectedJobID else {
            return
        }
        jobs.removeAll { job in
            job.id == selectedJobID && (job.status == .queued || job.status.isTerminal)
        }
        self.selectedJobID = jobs.first?.id
    }

    func setOutputDirectory(_ url: URL, for jobID: UUID) {
        updateJob(jobID) { job in
            job.outputDirectory = url
            job.usesAutomaticOutputDirectory = false
        }
    }

    func setDefaultOutputDirectory(_ url: URL?) {
        settings.defaultOutputDirectory = url
        UserDefaults.standard.set(url?.path, forKey: "defaultOutputDirectory")
    }

    func revealOutput(for job: ExtractionJob?) {
        guard let job else {
            return
        }
        NSWorkspace.shared.activateFileViewerSelecting([job.outputDirectory])
    }

    func startProcessing() {
        guard !isProcessing else {
            return
        }

        refreshTools()

        guard toolStatus.hasFFmpeg else {
            message = "ffmpeg is required. Install it with `brew install ffmpeg`."
            return
        }

        let queuedIDs = jobs
            .filter { $0.status.canProcess }
            .map(\.id)

        guard !queuedIDs.isEmpty else {
            message = "Add a video file or YouTube URL first."
            return
        }

        isProcessing = true

        processingTask = Task { [weak self] in
            guard let self else { return }
            for jobID in queuedIDs {
                if Task.isCancelled {
                    break
                }

                guard let snapshot = self.jobs.first(where: { $0.id == jobID }) else {
                    continue
                }

                if snapshot.inputType == .youtube && !self.toolStatus.hasYtDlp {
                    self.updateJob(jobID) { job in
                        job.status = .failed("yt-dlp is required for YouTube links. Install it with `brew install yt-dlp`.")
                    }
                    continue
                }

                let settingsSnapshot = self.settings
                let toolsSnapshot = self.toolStatus

                do {
                    let result = try await Task.detached(priority: .userInitiated) {
                        let service = ProcessingService(tools: toolsSnapshot)
                        return try await service.process(
                            job: snapshot,
                            settings: settingsSnapshot,
                            callbacks: ProcessingCallbacks(
                                updateStatus: { status in
                                    Task { @MainActor in
                                        self.updateJob(jobID) { $0.status = status }
                                    }
                                },
                                updateProgress: { progress in
                                    Task { @MainActor in
                                        self.updateJob(jobID) { $0.progress = progress }
                                    }
                                },
                                updateTitleAndOutput: { title, outputDirectory in
                                    Task { @MainActor in
                                        self.updateJob(jobID) {
                                            $0.title = title
                                            $0.outputDirectory = outputDirectory
                                        }
                                    }
                                }
                            )
                        )
                    }.value

                    self.updateJob(jobID) { job in
                        job.title = result.title
                        job.outputDirectory = result.outputDirectory
                        job.slides = result.export.slides
                        job.timeline = result.export.timeline
                        job.progress = 1.0
                        job.status = .completed
                    }
                } catch {
                    self.updateJob(jobID) { job in
                        job.status = .failed(error.localizedDescription)
                    }
                }
            }

            self.isProcessing = false
            self.processingTask = nil
        }
    }

    func cancelProcessing() {
        processingTask?.cancel()
        processingTask = nil
        isProcessing = false

        for job in jobs where !job.status.isTerminal {
            updateJob(job.id) { $0.status = .cancelled }
        }
    }

    private func updateJob(_ id: UUID, mutate: (inout ExtractionJob) -> Void) {
        guard let index = jobs.firstIndex(where: { $0.id == id }) else {
            return
        }
        mutate(&jobs[index])
    }

    private func installFormula(_ formula: String) {
        guard installingFormula == nil else {
            return
        }

        installingFormula = formula

        Task { [weak self] in
            guard let self else { return }
            do {
                try await Task.detached(priority: .userInitiated) {
                    try ToolInstallerService().install(formula: formula)
                }.value
                self.refreshTools()
                self.message = "\(formula) installed successfully."
            } catch {
                self.message = error.localizedDescription
            }
            self.installingFormula = nil
        }
    }

    private func deduplicatedOutputDirectory(_ proposed: URL) -> URL {
        let existingPaths = Set(jobs.map { $0.outputDirectory.path })
        guard existingPaths.contains(proposed.path) else {
            return proposed
        }

        let parent = proposed.deletingLastPathComponent()
        let baseName = proposed.lastPathComponent
        var index = 2
        var candidate = parent.appendingPathComponent("\(baseName) \(index)", isDirectory: true)

        while existingPaths.contains(candidate.path) || FileManager.default.fileExists(atPath: candidate.path) {
            index += 1
            candidate = parent.appendingPathComponent("\(baseName) \(index)", isDirectory: true)
        }

        return candidate
    }
}
