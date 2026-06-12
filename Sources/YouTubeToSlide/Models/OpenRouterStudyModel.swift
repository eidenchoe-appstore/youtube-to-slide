import Foundation

enum OpenRouterStudyModel: String, CaseIterable, Identifiable {
    case nemotronNano = "nvidia/nemotron-nano-12b-v2-vl:free"
    case gemma31B = "google/gemma-4-31b-it:free"
    case nemotronRerankVL = "nvidia/llama-nemotron-rerank-vl-1b-v2:free"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .nemotronNano:
            return "Nemotron Nano 12B VL"
        case .gemma31B:
            return "Gemma 4 31B"
        case .nemotronRerankVL:
            return "Nemotron Rerank VL 1B"
        }
    }

    var badge: String {
        switch self {
        case .nemotronNano:
            return "Default"
        case .gemma31B:
            return "Best overall"
        case .nemotronRerankVL:
            return "Fast"
        }
    }

    var advantage: String {
        switch self {
        case .nemotronNano:
            return "OCR, document understanding, charts, and slide-level multimodal comprehension."
        case .gemma31B:
            return "Strong image understanding, multilingual explanation, long-context synthesis, and instruction following."
        case .nemotronRerankVL:
            return "Useful when speed and lightweight visual relevance checks matter more than detailed explanation."
        }
    }

    static func model(for id: String) -> OpenRouterStudyModel {
        OpenRouterStudyModel(rawValue: id) ?? .nemotronNano
    }
}
