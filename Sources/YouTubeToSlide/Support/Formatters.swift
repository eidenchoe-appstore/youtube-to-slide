import Foundation

enum AppFormatters {
    static func timestamp(_ seconds: Double) -> String {
        let rounded = Int(seconds.rounded())
        let minutes = rounded / 60
        let remainder = rounded % 60
        if minutes == 0 {
            return "\(remainder)s"
        }
        return "\(minutes)m \(String(format: "%02d", remainder))s"
    }

    static func compactTimestampForFilename(_ seconds: Double) -> String {
        "\(Int(seconds.rounded()))s"
    }

    static func percent(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }
}
