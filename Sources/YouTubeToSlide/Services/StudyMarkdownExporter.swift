import Foundation

struct StudyMarkdownExporter {
    func export(job: ExtractionJob) throws -> URL {
        try FileManager.default.createDirectory(at: job.outputDirectory, withIntermediateDirectories: true)

        let safeTitle = FileNameSanitizer.sanitize(job.title)
        let outputURL = job.outputDirectory.appendingPathComponent("\(safeTitle).study-notes.md")
        let notesByIndex = job.studyNotes

        var lines: [String] = [
            "# \(job.title)",
            "",
            "- Source: \(job.source)",
            "- Generated: \(ISO8601DateFormatter().string(from: Date()))",
            "- Slides: \(job.slides.count)",
            "",
            "> Import this Markdown file into Notion from the same folder as the PNG slide images so relative image links can be resolved.",
            ""
        ]

        for slide in job.slides.sorted(by: { $0.index < $1.index }) {
            lines.append("## Slide \(slide.index) - \(AppFormatters.timestamp(slide.timestampSec))")
            lines.append("")
            lines.append("![Slide \(slide.index)](./\(slide.fileURL.lastPathComponent))")
            lines.append("")

            if let note = notesByIndex[slide.index] {
                lines.append(note.markdown.trimmingCharacters(in: .whitespacesAndNewlines))
            } else {
                lines.append("_No study note generated for this slide yet._")
            }

            lines.append("")
        }

        try lines.joined(separator: "\n").write(to: outputURL, atomically: true, encoding: .utf8)
        return outputURL
    }
}
