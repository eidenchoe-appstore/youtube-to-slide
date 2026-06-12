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
            ":root{--text:#37352f;--muted:#787774;--line:rgba(55,53,47,.16);--bg:#fff;--soft:#f7f6f3}",
            "body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Helvetica,Arial,sans-serif;line-height:1.55;margin:0;background:var(--bg);color:var(--text)}",
            ".page{max-width:900px;margin:0 auto;padding:64px 40px 96px}",
            "h1{font-size:40px;line-height:1.2;font-weight:700;margin:0 0 12px;letter-spacing:0}h2{font-size:26px;line-height:1.3;font-weight:650;margin:44px 0 10px;padding-top:24px;border-top:1px solid var(--line);letter-spacing:0}",
            "h3{font-size:19px;line-height:1.35;font-weight:650;margin:22px 0 8px;letter-spacing:0}p{margin:8px 0}.meta,.slide-meta{color:var(--muted);font-size:14px}",
            ".meta{margin-bottom:34px}.slide-image{display:block;max-width:100%;height:auto;border-radius:3px;margin:14px 0 18px}",
            ".note{margin-top:4px}.empty,.callout{background:var(--soft);border-radius:3px;padding:10px 12px;color:var(--muted)}",
            "pre{background:var(--soft);padding:12px;border-radius:3px;overflow:auto}code{font-family:ui-monospace,SFMono-Regular,Menlo,Consolas,monospace}ul{padding-left:1.5em;margin:6px 0 10px}li{margin:4px 0}",
            "</style>",
            "</head>",
            "<body>",
            "<main class=\"page\">",
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

            let note = studyNoteTitleAndBody(job.studyNotes[slide.index]?.markdown)
            let slideTitle = note.title ?? "Slide \(slide.index)"
            body.append("<h2>\(escapeHTML(slideTitle))</h2>")
            body.append("<div class=\"slide-meta\">Slide \(slide.index) · \(escapeHTML(AppFormatters.timestamp(slide.timestampSec)))</div>")
            body.append("<img class=\"slide-image\" src=\"assets/\(escapeAttribute(assetName))\" alt=\"Slide \(slide.index)\">")
            body.append("<div class=\"note\">")
            if !note.body.isEmpty {
                body.append(markdownToHTML(note.body))
            } else {
                body.append("<p class=\"empty\">No study note generated for this slide yet.</p>")
            }
            body.append("</div>")
        }

        body.append("</main>")
        body.append("</body>")
        body.append("</html>")
        return body.joined(separator: "\n")
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
