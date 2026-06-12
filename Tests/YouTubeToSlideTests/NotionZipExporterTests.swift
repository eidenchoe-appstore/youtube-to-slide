import XCTest
@testable import YouTubeToSlide

final class NotionZipExporterTests: XCTestCase {
    func testNotionZipExporterPackagesHTMLAndSlideAssets() throws {
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
            markdown: "## 핵심 요약\n- Important point",
            modelID: OpenRouterStudyModel.nemotronNano.id,
            generatedAt: Date()
        )

        let outputURL = try NotionZipExporter().export(job: job)
        let listing = try ShellService.run("/usr/bin/unzip", ["-l", outputURL.path]).stdout
        let html = try ShellService.run("/usr/bin/unzip", ["-p", outputURL.path, "Lecture.html"]).stdout

        XCTAssertTrue(listing.contains("Lecture.html"))
        XCTAssertTrue(listing.contains("assets/slide_000001_3s.png"))
        XCTAssertTrue(html.contains("<h1>Lecture</h1>"))
        XCTAssertTrue(html.contains("<img class=\"slide-image\" src=\"assets/slide_000001_3s.png\""))
        XCTAssertTrue(html.contains("<h3>핵심 요약</h3>"))
        XCTAssertTrue(html.contains("<li>Important point</li>"))
    }
}
