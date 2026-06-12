import Foundation

enum DevLogLevel: String, CaseIterable, Identifiable {
    case debug = "DEBUG"
    case info = "INFO"
    case success = "SUCCESS"
    case warning = "WARN"
    case error = "ERROR"

    var id: String { rawValue }
}

struct DevLogEntry: Identifiable, Equatable {
    let id: UUID
    var date: Date
    var level: DevLogLevel
    var message: String

    init(id: UUID = UUID(), date: Date = Date(), level: DevLogLevel, message: String) {
        self.id = id
        self.date = date
        self.level = level
        self.message = message
    }

    var line: String {
        "[\(timestamp)] [\(level.rawValue)] \(message)"
    }

    var timestamp: String {
        Self.dateFormatter.string(from: date)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()
}
