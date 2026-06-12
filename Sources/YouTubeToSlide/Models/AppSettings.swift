import Foundation

struct AppSettings: Equatable {
    var sampleInterval: Double = 2.5
    var changeThreshold: Double = 0.01
    var pixelDelta: Int = 25
    var compareWidth: Int = 160
    var resolution: ResolutionPreset = .original
    var customWidth: Int = 1920
    var exportPNG: Bool = true
    var exportPDF: Bool = false
    var exportPPTX: Bool = false
    var primaryStudyModelID: String = OpenRouterStudyModel.gemma31B.id
    var fallbackStudyModelID: String = OpenRouterStudyModel.gemma26BA4B.id
    var notionParentPageURL: String = ""
    var defaultOutputDirectory: URL?

    var studyModelIDs: [String] {
        var modelIDs: [String] = []
        for modelID in [primaryStudyModelID, fallbackStudyModelID]
        where OpenRouterStudyModel.isAvailable(modelID) && !modelIDs.contains(modelID) {
            modelIDs.append(modelID)
        }
        return modelIDs.isEmpty ? [OpenRouterStudyModel.gemma31B.id] : modelIDs
    }

    var selectedFormats: Set<OutputFormat> {
        var formats = Set<OutputFormat>()
        if exportPNG { formats.insert(.png) }
        if exportPDF { formats.insert(.pdf) }
        if exportPPTX { formats.insert(.pptx) }
        return formats
    }
}
