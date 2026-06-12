import XCTest
@testable import YouTubeToSlide

final class NotionZipExporterTests: XCTestCase {
    func testNotionZipExporterPackagesMarkdownAndSlideAssets() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("YouTubeToSlideNotionZipTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        let slideURL = root.appendingPathComponent("Lecture_000001_3s.png")
        try Data("png".utf8).write(to: slideURL)

        var job = ExtractionJob(
            inputType: .localVideo,
            source: "/tmp/lecture.mp4",
            title: "Lecture",
            outputDirectory: root
        )
        job.slides = [
            SlideFrame(index: 1, timestampSec: 2.5, fileURL: slideURL, changeRatio: 0)
        ]
        job.studyNotes[1] = SlideStudyNote(
            slideIndex: 1,
            timestampSec: 2.5,
            markdown: "# Binary Classification Performance\n\n#### 핵심 요약\n* Important point",
            modelID: OpenRouterStudyModel.nemotronNano.id,
            generatedAt: Date()
        )

        let outputURL = try NotionZipExporter().export(job: job)
        let listing = try ShellService.run("/usr/bin/unzip", ["-l", outputURL.path]).stdout
        let markdown = try ShellService.run("/usr/bin/unzip", ["-p", outputURL.path, "Lecture.md"]).stdout

        XCTAssertTrue(listing.contains("Lecture.md"))
        XCTAssertTrue(listing.contains("assets/slide_000001_3s.png"))
        XCTAssertTrue(markdown.contains("# Lecture"))
        XCTAssertTrue(markdown.contains("## Slide 1: Binary Classification Performance"))
        XCTAssertTrue(markdown.contains("![Slide 1](assets/slide_000001_3s.png)"))
        XCTAssertTrue(markdown.contains("### 핵심 요약"))
        XCTAssertTrue(markdown.contains("- Important point"))
        XCTAssertFalse(markdown.contains("#### 핵심 요약"))
        XCTAssertFalse(markdown.contains("Lecture.html"))
    }
}
