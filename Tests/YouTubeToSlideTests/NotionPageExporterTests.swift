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

    func testNotionConnectionIdentityDisplayNameIncludesWorkspace() throws {
        let json = """
        {
          "object": "user",
          "id": "9188c6a5-7381-452f-b3dc-d4865aa89bdf",
          "name": "YouTube to Slide",
          "avatar_url": null,
          "type": "bot",
          "bot": {
            "owner": {
              "type": "workspace",
              "workspace": true
            },
            "workspace_name": "Lecture Workspace"
          }
        }
        """.data(using: .utf8)!

        let identity = try JSONDecoder().decode(NotionConnectionIdentity.self, from: json)

        XCTAssertEqual(identity.displayName, "YouTube to Slide · Lecture Workspace")
    }

    func testNotionConnectionIdentityFallsBackWhenNameIsMissing() throws {
        let json = """
        {
          "object": "user",
          "id": "9188c6a5-7381-452f-b3dc-d4865aa89bdf",
          "name": null,
          "avatar_url": null,
          "type": "bot",
          "bot": {}
        }
        """.data(using: .utf8)!

        let identity = try JSONDecoder().decode(NotionConnectionIdentity.self, from: json)

        XCTAssertEqual(identity.displayName, "Unnamed Notion connection")
    }
}
