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
    var defaultOutputDirectory: URL?

    var selectedFormats: Set<OutputFormat> {
        var formats = Set<OutputFormat>()
        if exportPNG { formats.insert(.png) }
        if exportPDF { formats.insert(.pdf) }
        if exportPPTX { formats.insert(.pptx) }
        return formats
    }
}
