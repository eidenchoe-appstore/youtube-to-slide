import XCTest
@testable import YouTubeToSlide

final class StudyMarkdownExporterTests: XCTestCase {
    func testMarkdownExporterUsesRelativeSlideImageLinks() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("YouTubeToSlideMarkdownTests-\(UUID().uuidString)", isDirectory: true)
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
            markdown: "## 핵심 요약\n- Important point",
            modelID: OpenRouterStudyModel.nemotronNano.id,
            generatedAt: Date()
        )

        let outputURL = try StudyMarkdownExporter().export(job: job)
        let markdown = try String(contentsOf: outputURL, encoding: .utf8)

        XCTAssertTrue(markdown.contains("![Slide 1](./Lecture_000001_3s.png)"))
        XCTAssertTrue(markdown.contains("## 핵심 요약"))
    }
}
