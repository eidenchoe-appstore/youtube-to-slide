import Foundation

struct SlideStudyNote: Identifiable, Codable, Equatable {
    var id: Int { slideIndex }
    var slideIndex: Int
    var timestampSec: Double
    var markdown: String
    var modelID: String
    var generatedAt: Date
}

struct StudyChatMessage: Identifiable, Equatable {
    let id: UUID
    var role: StudyChatRole
    var content: String
    var createdAt: Date

    init(id: UUID = UUID(), role: StudyChatRole, content: String, createdAt: Date = Date()) {
        self.id = id
        self.role = role
        self.content = content
        self.createdAt = createdAt
    }
}

enum StudyChatRole: String, Codable, Equatable {
    case user
    case assistant

    var label: String {
        switch self {
        case .user:
            return "You"
        case .assistant:
            return "Study Assistant"
        }
    }
}

enum StudyChatScope: String, CaseIterable, Identifiable {
    case selectedSlide
    case allSlides

    var id: String { rawValue }

    var label: String {
        switch self {
        case .selectedSlide:
            return "Selected slide"
        case .allSlides:
            return "All slides"
        }
    }
}
