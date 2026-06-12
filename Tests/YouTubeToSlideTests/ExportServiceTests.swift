import AppKit
import XCTest
@testable import YouTubeToSlide

final class ExportServiceTests: XCTestCase {
    func testPPTXUsesExtractedFrameAspectRatio() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("YouTubeToSlideTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        let frameURL = root.appendingPathComponent("frame.png")
        try writePNG(width: 800, height: 600, to: frameURL)

        let result = try ExportService().export(
            candidates: [
                SlideCandidate(frameURL: frameURL, timestampSec: 2.5, changeRatio: 0)
            ],
            title: "Aspect Test",
            outputDirectory: root,
            formats: [.pptx]
        )

        let pptxURL = try XCTUnwrap(result.pptxURL)
        let presentation = try ShellService.run(
            "/usr/bin/unzip",
            ["-p", pptxURL.path, "ppt/presentation.xml"]
        ).stdout
        let slide = try ShellService.run(
            "/usr/bin/unzip",
            ["-p", pptxURL.path, "ppt/slides/slide1.xml"]
        ).stdout

        XCTAssertTrue(presentation.contains(#"<p:sldSz cx="9144000" cy="6858000" type="custom"/>"#))
        XCTAssertTrue(slide.contains(#"<a:ext cx="9144000" cy="6858000"/>"#))
    }

    private func writePNG(width: Int, height: Int, to url: URL) throws {
        let image = NSImage(size: NSSize(width: width, height: height))
        image.lockFocus()
        NSColor.white.setFill()
        NSBezierPath(rect: NSRect(x: 0, y: 0, width: width, height: height)).fill()
        image.unlockFocus()

        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            XCTFail("Could not create test PNG.")
            return
        }

        try pngData.write(to: url)
    }
}
