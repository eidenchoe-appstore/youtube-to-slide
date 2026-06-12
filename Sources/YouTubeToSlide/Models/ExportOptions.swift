import Foundation

enum OutputFormat: String, CaseIterable, Identifiable {
    case png
    case pdf
    case pptx

    var id: String { rawValue }

    var label: String {
        rawValue.uppercased()
    }
}

enum ResolutionPreset: String, CaseIterable, Identifiable {
    case original
    case fullHD
    case hd
    case customWidth

    var id: String { rawValue }

    var label: String {
        switch self {
        case .original:
            return "Original"
        case .fullHD:
            return "1080p"
        case .hd:
            return "720p"
        case .customWidth:
            return "Custom width"
        }
    }

    var ffmpegScaleFilter: String? {
        switch self {
        case .original:
            return nil
        case .fullHD:
            return "scale=-2:1080"
        case .hd:
            return "scale=-2:720"
        case .customWidth:
            return nil
        }
    }
}
