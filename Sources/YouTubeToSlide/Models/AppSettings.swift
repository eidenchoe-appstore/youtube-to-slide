import Foundation

struct AppSettings: Equatable {
    var sampleInterval: Double = 1.0
    var changeThreshold: Double = 0.25
    var pixelDelta: Int = 25
    var compareWidth: Int = 320
    var resolution: ResolutionPreset = .original
    var customWidth: Int = 1920
    var exportPNG: Bool = true
    var exportPDF: Bool = true
    var exportPPTX: Bool = true
    var defaultOutputDirectory: URL?

    var selectedFormats: Set<OutputFormat> {
        var formats = Set<OutputFormat>()
        if exportPNG { formats.insert(.png) }
        if exportPDF { formats.insert(.pdf) }
        if exportPPTX { formats.insert(.pptx) }
        return formats
    }
}
