import XCTest
@testable import YouTubeToSlide

final class NotionMarkdownRendererTests: XCTestCase {
    func testInlineRichTextFormattingIsConvertedToNotionAnnotations() throws {
        let blocks = NotionMarkdownRenderer().blocks(
            from: "- **Carry** uses `C` and $2^5$ with <span color=\"red\">overflow</span> plus [docs](https://example.com)"
        )

        let richText = try richTextPayload(in: blocks[0], key: "bulleted_list_item")

        XCTAssertTrue(containsText("Carry", in: richText, annotation: "bold"))
        XCTAssertTrue(containsText("C", in: richText, annotation: "code"))
        XCTAssertTrue(containsEquation("2^5", in: richText))
        XCTAssertTrue(containsText("overflow", in: richText, color: "red"))
        XCTAssertTrue(containsText("docs", in: richText, link: "https://example.com"))
    }

    func testCalloutBlockSupportsColorIconAndChildren() throws {
        let blocks = NotionMarkdownRenderer().blocks(
            from: """
            <callout icon="⚠️" color="yellow_bg">
            \t**Careful** with `BCS`
            \t- Carry = NOT Borrow
            </callout>
            """
        )

        XCTAssertEqual(blocks.count, 1)
        let callout = try XCTUnwrap(blocks[0]["callout"] as? [String: Any])
        XCTAssertEqual(callout["color"] as? String, "yellow_bg")
        let icon = try XCTUnwrap(callout["icon"] as? [String: Any])
        XCTAssertEqual(icon["emoji"] as? String, "⚠️")

        let richText = try XCTUnwrap(callout["rich_text"] as? [[String: Any]])
        XCTAssertTrue(containsText("Careful", in: richText, annotation: "bold"))
        XCTAssertTrue(containsText("BCS", in: richText, annotation: "code"))

        let children = try XCTUnwrap(callout["children"] as? [[String: Any]])
        XCTAssertEqual(children.first?["type"] as? String, "bulleted_list_item")
    }

    func testMarkdownTableIsConvertedToNotionTableBlock() throws {
        let blocks = NotionMarkdownRenderer().blocks(
            from: """
            | Flag | Meaning |
            |---|---|
            | **C** | $carry$ |
            """
        )

        XCTAssertEqual(blocks.count, 1)
        let table = try XCTUnwrap(blocks[0]["table"] as? [String: Any])
        XCTAssertEqual(table["table_width"] as? Int, 2)
        XCTAssertEqual(table["has_column_header"] as? Bool, true)

        let rows = try XCTUnwrap(table["children"] as? [[String: Any]])
        XCTAssertEqual(rows.count, 2)
        let secondRow = try XCTUnwrap(rows[1]["table_row"] as? [String: Any])
        let cells = try XCTUnwrap(secondRow["cells"] as? [[[String: Any]]])
        XCTAssertTrue(containsText("C", in: cells[0], annotation: "bold"))
        XCTAssertTrue(containsEquation("carry", in: cells[1]))
    }

    private func richTextPayload(in block: [String: Any], key: String) throws -> [[String: Any]] {
        let payload = try XCTUnwrap(block[key] as? [String: Any])
        return try XCTUnwrap(payload["rich_text"] as? [[String: Any]])
    }

    private func containsText(
        _ content: String,
        in richText: [[String: Any]],
        annotation: String? = nil,
        color: String? = nil,
        link: String? = nil
    ) -> Bool {
        richText.contains { item in
            guard item["type"] as? String == "text",
                  let text = item["text"] as? [String: Any],
                  text["content"] as? String == content else {
                return false
            }

            if let annotation {
                let annotations = item["annotations"] as? [String: Any]
                guard annotations?[annotation] as? Bool == true else {
                    return false
                }
            }

            if let color {
                let annotations = item["annotations"] as? [String: Any]
                guard annotations?["color"] as? String == color else {
                    return false
                }
            }

            if let link {
                let textLink = text["link"] as? [String: Any]
                guard textLink?["url"] as? String == link else {
                    return false
                }
            }

            return true
        }
    }

    private func containsEquation(_ expression: String, in richText: [[String: Any]]) -> Bool {
        richText.contains { item in
            guard item["type"] as? String == "equation",
                  let equation = item["equation"] as? [String: Any] else {
                return false
            }
            return equation["expression"] as? String == expression
        }
    }
}
