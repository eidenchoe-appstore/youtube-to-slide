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

        let htmlURL = buildRoot.appendingPathComponent("\(safeTitle).html")
        try html(for: job, safeTitle: safeTitle, assetsDirectory: assetsDirectory)
            .write(to: htmlURL, atomically: true, encoding: .utf8)

        let outputURL = job.outputDirectory.appendingPathComponent("\(safeTitle).notion-page.zip")
        if fileManager.fileExists(atPath: outputURL.path) {
            try fileManager.removeItem(at: outputURL)
        }

        guard let zipPath = ToolResolver.resolveExecutable(named: "zip") ?? (fileManager.isExecutableFile(atPath: "/usr/bin/zip") ? "/usr/bin/zip" : nil) else {
            throw NotionZipExportError.zipUnavailable
        }

        try ShellService.run(
            zipPath,
            ["-qr", outputURL.path, "\(safeTitle).html", "assets"],
            currentDirectory: buildRoot
        )

        return outputURL
    }

    private func html(for job: ExtractionJob, safeTitle: String, assetsDirectory: URL) throws -> String {
        let slides = job.slides.sorted { $0.index < $1.index }
        let generatedAt = ISO8601DateFormatter().string(from: Date())

        var body: [String] = [
            "<!doctype html>",
            "<html>",
            "<head>",
            "<meta charset=\"utf-8\">",
            "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">",
            "<title>\(escapeHTML(job.title))</title>",
            "<style>",
            "body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;line-height:1.55;margin:40px;max-width:1040px;color:#1f2328}",
            "h1{font-size:34px;margin-bottom:8px}h2{font-size:24px;margin-top:36px;border-top:1px solid #d8dee4;padding-top:24px}",
            ".meta{color:#57606a;margin-bottom:28px}.slide-image{max-width:100%;height:auto;border:1px solid #d8dee4;border-radius:8px}",
            ".note{margin-top:16px}.empty{color:#57606a;font-style:italic}pre{background:#f6f8fa;padding:12px;border-radius:8px;overflow:auto}",
            "code{font-family:ui-monospace,SFMono-Regular,Menlo,Consolas,monospace}li{margin:4px 0}",
            "</style>",
            "</head>",
            "<body>",
            "<h1>\(escapeHTML(job.title))</h1>",
            "<div class=\"meta\">",
            "<div>Source: \(escapeHTML(job.source))</div>",
            "<div>Generated: \(escapeHTML(generatedAt))</div>",
            "<div>Slides: \(slides.count)</div>",
            "</div>"
        ]

        for slide in slides {
            let assetName = "slide_\(String(format: "%06d", slide.index))_\(AppFormatters.compactTimestampForFilename(slide.timestampSec)).png"
            let assetURL = assetsDirectory.appendingPathComponent(assetName)
            if FileManager.default.fileExists(atPath: assetURL.path) {
                try FileManager.default.removeItem(at: assetURL)
            }
            try FileManager.default.copyItem(at: slide.fileURL, to: assetURL)

            body.append("<h2>Slide \(slide.index) · \(escapeHTML(AppFormatters.timestamp(slide.timestampSec)))</h2>")
            body.append("<img class=\"slide-image\" src=\"assets/\(escapeAttribute(assetName))\" alt=\"Slide \(slide.index)\">")
            body.append("<div class=\"note\">")
            if let note = job.studyNotes[slide.index],
               !note.markdown.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                body.append(markdownToHTML(note.markdown))
            } else {
                body.append("<p class=\"empty\">No study note generated for this slide yet.</p>")
            }
            body.append("</div>")
        }

        body.append("</body>")
        body.append("</html>")
        return body.joined(separator: "\n")
    }

    private func markdownToHTML(_ markdown: String) -> String {
        var html: [String] = []
        var isInList = false
        var isInCodeBlock = false
        var codeLines: [String] = []

        func closeListIfNeeded() {
            if isInList {
                html.append("</ul>")
                isInList = false
            }
        }

        for rawLine in markdown.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)

            if line.hasPrefix("```") {
                closeListIfNeeded()
                if isInCodeBlock {
                    html.append("<pre><code>\(escapeHTML(codeLines.joined(separator: "\n")))</code></pre>")
                    codeLines.removeAll()
                    isInCodeBlock = false
                } else {
                    isInCodeBlock = true
                }
                continue
            }

            if isInCodeBlock {
                codeLines.append(rawLine)
                continue
            }

            if line.isEmpty {
                closeListIfNeeded()
                continue
            }

            if line.hasPrefix("### ") {
                closeListIfNeeded()
                html.append("<h3>\(escapeHTML(String(line.dropFirst(4))))</h3>")
            } else if line.hasPrefix("## ") {
                closeListIfNeeded()
                html.append("<h3>\(escapeHTML(String(line.dropFirst(3))))</h3>")
            } else if line.hasPrefix("# ") {
                closeListIfNeeded()
                html.append("<h2>\(escapeHTML(String(line.dropFirst(2))))</h2>")
            } else if line.hasPrefix("- ") || line.hasPrefix("* ") {
                if !isInList {
                    html.append("<ul>")
                    isInList = true
                }
                html.append("<li>\(escapeHTML(String(line.dropFirst(2))))</li>")
            } else {
                closeListIfNeeded()
                html.append("<p>\(escapeHTML(line))</p>")
            }
        }

        if isInCodeBlock {
            html.append("<pre><code>\(escapeHTML(codeLines.joined(separator: "\n")))</code></pre>")
        }
        closeListIfNeeded()

        return html.joined(separator: "\n")
    }

    private func escapeHTML(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }

    private func escapeAttribute(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? escapeHTML(value)
    }
}
