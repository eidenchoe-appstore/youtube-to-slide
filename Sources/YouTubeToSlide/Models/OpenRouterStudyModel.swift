import Foundation

enum OpenRouterStudyModel: String, CaseIterable, Identifiable {
    case nemotron3NanoOmni = "nvidia/nemotron-3-nano-omni-30b-a3b-reasoning:free"
    case gemma26BA4B = "google/gemma-4-26b-a4b-it:free"
    case gemma31B = "google/gemma-4-31b-it:free"

    static let defaultPrimaryID = OpenRouterStudyModel.nemotron3NanoOmni.id
    static let defaultFallbackID = OpenRouterStudyModel.gemma26BA4B.id

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
        case .nemotron3NanoOmni:
            return "Default first model"
        case .gemma26BA4B:
            return "Default fallback"
        case .gemma31B:
            return "High-capacity option"
        }
    }

    var advantage: String {
        switch self {
        case .nemotron3NanoOmni:
            return "Fast reasoning-oriented default for quick slide study notes when throughput matters."
        case .gemma26BA4B:
            return "Balanced fallback for Korean/English slide explanation with lower load than 31B."
        case .gemma31B:
            return "High-capacity slide understanding, multilingual summaries, and instruction-following."
        }
    }

    static func isPreset(_ id: String) -> Bool {
        OpenRouterStudyModel(rawValue: id) != nil
    }

    static func preset(for id: String) -> OpenRouterStudyModel? {
        OpenRouterStudyModel(rawValue: id)
    }

    static func sanitizedModelID(_ id: String) -> String {
        id.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func isUsableModelID(_ id: String) -> Bool {
        !sanitizedModelID(id).isEmpty
    }

    static func modelDescription(for id: String) -> (displayName: String, badge: String, advantage: String) {
        if let preset = preset(for: id) {
            return (preset.displayName, preset.badge, preset.advantage)
        }

        let modelID = sanitizedModelID(id)
        return (
            modelID.isEmpty ? "Custom model" : "Custom model",
            "Custom OpenRouter model ID",
            modelID.isEmpty
                ? "Enter an OpenRouter model ID such as google/gemma-4-31b-it:free."
                : "The app will send this exact model ID to OpenRouter."
        )
    }
}
