import Foundation

enum OpenRouterStudyModel: String, CaseIterable, Identifiable {
    case gemma31B = "google/gemma-4-31b-it:free"
    case gemma26BA4B = "google/gemma-4-26b-a4b-it:free"
    case nemotron3NanoOmni = "nvidia/nemotron-3-nano-omni-30b-a3b-reasoning:free"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .gemma31B:
            return "Gemma 4 31B (free)"
        case .gemma26BA4B:
            return "Gemma 4 26B A4B (free)"
        case .nemotron3NanoOmni:
            return "Nemotron 3 Nano Omni (free)"
        }
    }

    var badge: String {
        switch self {
        case .gemma31B:
            return "Best overall"
        case .gemma26BA4B:
            return "Balanced backup"
        case .nemotron3NanoOmni:
            return "Fast reasoning"
        }
    }

    var advantage: String {
        switch self {
        case .gemma31B:
            return "Best default for slide understanding, multilingual summaries, and instruction-following."
        case .gemma26BA4B:
            return "Balanced backup for Korean/English slide explanation with lower load than 31B."
        case .nemotron3NanoOmni:
            return "Fast reasoning-oriented backup for quick slide study notes when throughput matters."
        }
    }

    static func isAvailable(_ id: String) -> Bool {
        OpenRouterStudyModel(rawValue: id) != nil
    }

    static func model(for id: String) -> OpenRouterStudyModel {
        OpenRouterStudyModel(rawValue: id) ?? .gemma31B
    }
}
