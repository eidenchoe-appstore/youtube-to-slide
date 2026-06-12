import Foundation

enum FileNameSanitizer {
    static func sanitize(_ rawValue: String, fallback: String = "Untitled") -> String {
        let illegalCharacters = CharacterSet(charactersIn: "/\\?%*|\"<>:")
            .union(.newlines)
            .union(.controlCharacters)

        let parts = rawValue
            .components(separatedBy: illegalCharacters)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")

        let sanitized = parts.trimmingCharacters(in: CharacterSet(charactersIn: ". "))
        if sanitized.isEmpty {
            return fallback
        }

        return String(sanitized.prefix(120))
    }
}

enum OutputPathResolver {
    static func defaultDownloadsRoot() -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Downloads")
            .appendingPathComponent("YouTube to Slide")
    }

    static func localOutputDirectory(for fileURL: URL) -> URL {
        let title = FileNameSanitizer.sanitize(fileURL.deletingPathExtension().lastPathComponent)
        return uniqueDirectory(parent: fileURL.deletingLastPathComponent(), title: title)
    }

    static func youtubeOutputDirectory(title: String, preferredRoot: URL?) -> URL {
        let root = preferredRoot ?? defaultDownloadsRoot()
        return uniqueDirectory(parent: root, title: FileNameSanitizer.sanitize(title, fallback: "YouTube Video"))
    }

    static func uniqueDirectory(parent: URL, title: String) -> URL {
        let fileManager = FileManager.default
        let safeTitle = FileNameSanitizer.sanitize(title)
        var candidate = parent.appendingPathComponent(safeTitle, isDirectory: true)
        var index = 2

        while fileManager.fileExists(atPath: candidate.path) {
            candidate = parent.appendingPathComponent("\(safeTitle) \(index)", isDirectory: true)
            index += 1
        }

        return candidate
    }
}
