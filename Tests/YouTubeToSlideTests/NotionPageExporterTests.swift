import XCTest
@testable import YouTubeToSlide

final class NotionPageExporterTests: XCTestCase {
    func testParentPageIDParserAcceptsCompactNotionURL() {
        let parsed = NotionParentPageIDParser.parse(
            "https://www.notion.so/workspace/Lecture-1234567890abcdef1234567890abcdef?pvs=4"
        )

        XCTAssertEqual(parsed, "12345678-90ab-cdef-1234-567890abcdef")
    }

    func testParentPageIDParserAcceptsDashedPageID() {
        let parsed = NotionParentPageIDParser.parse("12345678-90ab-cdef-1234-567890abcdef")

        XCTAssertEqual(parsed, "12345678-90ab-cdef-1234-567890abcdef")
    }

    func testParentPageIDParserRejectsInvalidInput() {
        XCTAssertNil(NotionParentPageIDParser.parse("https://www.notion.so/not-a-page"))
    }
}
