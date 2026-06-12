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
    var primaryStudyModelID: String = OpenRouterStudyModel.defaultPrimaryID
    var fallbackStudyModelID: String = OpenRouterStudyModel.defaultFallbackID
    var notionParentPageURL: String = ""
    var defaultOutputDirectory: URL?

    var studyModelIDs: [String] {
        var modelIDs: [String] = []
        for modelID in [primaryStudyModelID, fallbackStudyModelID]
        where OpenRouterStudyModel.isUsableModelID(modelID) {
            let trimmed = OpenRouterStudyModel.sanitizedModelID(modelID)
            if !modelIDs.contains(trimmed) {
                modelIDs.append(trimmed)
            }
        }
        return modelIDs.isEmpty ? [OpenRouterStudyModel.defaultPrimaryID] : modelIDs
    }

    var selectedFormats: Set<OutputFormat> {
        var formats = Set<OutputFormat>()
        if exportPNG { formats.insert(.png) }
        if exportPDF { formats.insert(.pdf) }
        if exportPPTX { formats.insert(.pptx) }
        return formats
    }
}
