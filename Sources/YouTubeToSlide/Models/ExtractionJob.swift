import Foundation

enum InputType: String, CaseIterable, Identifiable, Codable {
    case localVideo
    case youtube

    var id: String { rawValue }

    var label: String {
        switch self {
        case .localVideo:
            return "Video"
        case .youtube:
            return "YouTube"
        }
    }

    var systemImage: String {
        switch self {
        case .localVideo:
            return "film"
        case .youtube:
            return "play.rectangle"
        }
    }
}

enum JobStatus: Equatable {
    case queued
    case preparing
    case extracting
    case analyzing
    case exporting
    case completed
    case cancelled
    case failed(String)

    var label: String {
        switch self {
        case .queued:
            return "Queued"
        case .preparing:
            return "Preparing"
        case .extracting:
            return "Extracting frames"
        case .analyzing:
            return "Analyzing changes"
        case .exporting:
            return "Exporting"
        case .completed:
            return "Completed"
        case .cancelled:
            return "Cancelled"
        case .failed:
            return "Failed"
        }
    }

    var detail: String? {
        if case let .failed(message) = self {
            return message
        }
        return nil
    }

    var isTerminal: Bool {
        switch self {
        case .completed, .cancelled, .failed:
            return true
        default:
            return false
        }
    }

    var canProcess: Bool {
        switch self {
        case .queued, .cancelled, .failed:
            return true
        default:
            return false
        }
    }
}

struct ExtractionJob: Identifiable, Equatable {
    let id: UUID
    var inputType: InputType
    var source: String
    var sourceURL: URL?
    var title: String
    var outputDirectory: URL
    var usesAutomaticOutputDirectory: Bool
    var status: JobStatus
    var progress: Double
    var slides: [SlideFrame]
    var timeline: [TimelineEntry]
    var youtubePreview: YouTubePreview?
    var studyNotes: [Int: SlideStudyNote]
    var chatMessages: [StudyChatMessage]
    var notionZipURL: URL?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        inputType: InputType,
        source: String,
        sourceURL: URL? = nil,
        title: String,
        outputDirectory: URL,
        usesAutomaticOutputDirectory: Bool = true,
        youtubePreview: YouTubePreview? = nil
    ) {
        self.id = id
        self.inputType = inputType
        self.source = source
        self.sourceURL = sourceURL
        self.title = title
        self.outputDirectory = outputDirectory
        self.usesAutomaticOutputDirectory = usesAutomaticOutputDirectory
        self.status = .queued
        self.progress = 0
        self.slides = []
        self.timeline = []
        self.youtubePreview = youtubePreview
        self.studyNotes = [:]
        self.chatMessages = []
        self.notionZipURL = nil
        self.createdAt = Date()
    }
}
