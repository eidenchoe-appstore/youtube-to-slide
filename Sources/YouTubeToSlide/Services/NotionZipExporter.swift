import Foundation

enum NotionZipExportError: LocalizedError {
    case noSlides
    case zipUnavailable

    var errorDescription: String? {
        switch self {
        case .noSlides:
            return "Extract slides before creating a Notion page ZIP."
        case .zipUnavailable:
            return "Could not find the macOS zip tool."
        }
    }
}

struct NotionZipExporter {
    func export(job: ExtractionJob) throws -> URL {
        guard !job.slides.isEmpty else {
            throw NotionZipExportError.noSlides
        }

        let fileManager = FileManager.default
        try fileManager.createDirectory(at: job.outputDirectory, withIntermediateDirectories: true)

        let safeTitle = FileNameSanitizer.sanitize(job.title)
        let buildRoot = job.outputDirectory
            .appendingPathComponent(".notion-page-\(UUID().uuidString)", isDirectory: true)
        let assetsDirectory = buildRoot.appendingPathComponent("assets", isDirectory: true)
        defer { try? fileManager.removeItem(at: buildRoot) }

        try fileManager.createDirectory(at: assetsDirectory, withIntermediateDirectories: true)

        let markdownURL = buildRoot.appendingPathComponent("\(safeTitle).md")
        try markdown(for: job, assetsDirectory: assetsDirectory)
            .write(to: markdownURL, atomically: true, encoding: .utf8)

        let outputURL = job.outputDirectory.appendingPathComponent("\(safeTitle).notion-page.zip")
        if fileManager.fileExists(atPath: outputURL.path) {
            try fileManager.removeItem(at: outputURL)
        }

        guard let zipPath = ToolResolver.resolveExecutable(named: "zip") ?? (fileManager.isExecutableFile(atPath: "/usr/bin/zip") ? "/usr/bin/zip" : nil) else {
            throw NotionZipExportError.zipUnavailable
        }

        try ShellService.run(
            zipPath,
            ["-qr", outputURL.path, "\(safeTitle).md", "assets"],
            currentDirectory: buildRoot
        )

        return outputURL
    }

    private func markdown(for job: ExtractionJob, assetsDirectory: URL) throws -> String {
        let slides = job.slides.sorted { $0.index < $1.index }
        let generatedAt = ISO8601DateFormatter().string(from: Date())

        var lines: [String] = [
            "# \(markdownHeadingText(job.title))",
            "",
            "- Source: \(job.source)",
            "- Generated: \(generatedAt)",
            "- Slides: \(slides.count)",
            "",
            "---",
            ""
        ]

        for slide in slides {
            let assetName = "slide_\(String(format: "%06d", slide.index))_\(AppFormatters.compactTimestampForFilename(slide.timestampSec)).png"
            let assetURL = assetsDirectory.appendingPathComponent(assetName)
            if FileManager.default.fileExists(atPath: assetURL.path) {
                try FileManager.default.removeItem(at: assetURL)
            }
            try FileManager.default.copyItem(at: slide.fileURL, to: assetURL)

            let note = studyNoteTitleAndBody(job.studyNotes[slide.index]?.markdown)
            let slideTitle = note.title ?? "Slide \(slide.index)"

            lines.append("## Slide \(slide.index): \(markdownHeadingText(slideTitle))")
            lines.append("")
            lines.append("![Slide \(slide.index)](assets/\(assetName))")
            lines.append("")

            if note.body.isEmpty {
                lines.append("_No study note generated for this slide yet._")
            } else {
                lines.append(normalizeStudyNoteBody(note.body))
            }

            lines.append("")
            lines.append("---")
            lines.append("")
        }

        return lines.joined(separator: "\n")
    }

    private func studyNoteTitleAndBody(_ markdown: String?) -> (title: String?, body: String) {
        guard let markdown else {
            return (nil, "")
        }

        var lines = markdown
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .newlines)

        while let first = lines.first,
              first.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            lines.removeFirst()
        }

        guard let firstLine = lines.first?.trimmingCharacters(in: .whitespacesAndNewlines) else {
            return (nil, "")
        }

        let headingPrefixes = ["# ", "## ", "### "]
        if let prefix = headingPrefixes.first(where: { firstLine.hasPrefix($0) }) {
            lines.removeFirst()
            let title = String(firstLine.dropFirst(prefix.count))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return (title.isEmpty ? nil : title, lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines))
        }

        return (nil, lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private func normalizeStudyNoteBody(_ markdown: String) -> String {
        var normalizedLines: [String] = []
        var isInCodeBlock = false

        for rawLine in markdown.components(separatedBy: .newlines) {
            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("```") {
                isInCodeBlock.toggle()
                normalizedLines.append(rawLine)
                continue
            }

            if isInCodeBlock {
                normalizedLines.append(rawLine)
                continue
            }

            if trimmed.hasPrefix("###### ")
                || trimmed.hasPrefix("##### ")
                || trimmed.hasPrefix("#### ")
                || trimmed.hasPrefix("### ")
                || trimmed.hasPrefix("## ")
                || trimmed.hasPrefix("# ") {
                let headingText = trimmed.drop { $0 == "#" || $0 == " " }
                normalizedLines.append("### \(markdownHeadingText(String(headingText)))")
            } else if trimmed.hasPrefix("* ") || trimmed.hasPrefix("+ ") {
                let indentation = String(rawLine.prefix { $0 == " " || $0 == "\t" })
                normalizedLines.append("\(indentation)- \(trimmed.dropFirst(2))")
            } else {
                normalizedLines.append(rawLine)
            }
        }

        return normalizedLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func markdownHeadingText(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
