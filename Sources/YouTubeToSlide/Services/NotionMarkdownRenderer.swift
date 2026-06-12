import Foundation

struct NotionMarkdownRenderer {
    func blocks(from markdown: String) -> [[String: Any]] {
        var blocks: [[String: Any]] = []
        var codeLines: [String] = []
        var codeLanguage = "plain text"
        var isInCodeBlock = false
        var equationLines: [String] = []
        var isInEquationBlock = false
        var tableLines: [String] = []
        var calloutLines: [String] = []
        var calloutAttributes: [String: String] = [:]
        var isInCallout = false

        func flushTable() {
            guard !tableLines.isEmpty else { return }
            if let table = tableBlock(from: tableLines) {
                blocks.append(table)
            } else {
                blocks.append(contentsOf: tableLines.map { paragraphBlock($0) })
            }
            tableLines.removeAll()
        }

        for rawLine in markdown
            .replacingOccurrences(of: "\r\n", with: "\n")
            .components(separatedBy: "\n") {
            let trimmed = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)

            if isInCodeBlock {
                if trimmed.hasPrefix("```") {
                    blocks.append(codeBlock(codeLines.joined(separator: "\n"), language: codeLanguage))
                    codeLines.removeAll()
                    codeLanguage = "plain text"
                    isInCodeBlock = false
                } else {
                    codeLines.append(rawLine)
                }
                continue
            }

            if isInEquationBlock {
                if trimmed == "$$" {
                    blocks.append(equationBlock(equationLines.joined(separator: "\n")))
                    equationLines.removeAll()
                    isInEquationBlock = false
                } else {
                    equationLines.append(rawLine)
                }
                continue
            }

            if isInCallout {
                if trimmed == "</callout>" {
                    blocks.append(calloutBlock(lines: calloutLines, attributes: calloutAttributes))
                    calloutLines.removeAll()
                    calloutAttributes.removeAll()
                    isInCallout = false
                } else {
                    calloutLines.append(strippingOneLeadingTab(rawLine))
                }
                continue
            }

            if trimmed.hasPrefix("```") {
                flushTable()
                codeLanguage = normalizedCodeLanguage(String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespacesAndNewlines))
                isInCodeBlock = true
                continue
            }

            if trimmed == "$$" {
                flushTable()
                isInEquationBlock = true
                continue
            }

            if trimmed.hasPrefix("$$"), trimmed.hasSuffix("$$"), trimmed.count > 4 {
                flushTable()
                let expression = String(trimmed.dropFirst(2).dropLast(2)).trimmingCharacters(in: .whitespacesAndNewlines)
                blocks.append(equationBlock(expression))
                continue
            }

            if trimmed.hasPrefix("<callout") {
                flushTable()
                calloutAttributes = attributes(from: trimmed)
                isInCallout = !trimmed.contains("</callout>")
                if let inlineBody = inlineCalloutBody(from: trimmed) {
                    blocks.append(calloutBlock(lines: [inlineBody], attributes: calloutAttributes))
                    calloutAttributes.removeAll()
                    isInCallout = false
                }
                continue
            }

            if trimmed.isEmpty {
                flushTable()
                continue
            }

            if isTableLine(trimmed) {
                tableLines.append(rawLine)
                continue
            }

            flushTable()
            blocks.append(contentsOf: block(from: trimmed))
        }

        if isInCodeBlock || !codeLines.isEmpty {
            blocks.append(codeBlock(codeLines.joined(separator: "\n"), language: codeLanguage))
        }
        if isInEquationBlock || !equationLines.isEmpty {
            blocks.append(equationBlock(equationLines.joined(separator: "\n")))
        }
        if isInCallout || !calloutLines.isEmpty {
            blocks.append(calloutBlock(lines: calloutLines, attributes: calloutAttributes))
        }
        flushTable()

        return blocks
    }

    func richText(_ text: String) -> [[String: Any]] {
        parseInline(text, annotations: InlineAnnotations())
    }

    func plainRichText(_ text: String) -> [[String: Any]] {
        splitText(text).map { textObject(content: $0, annotations: InlineAnnotations()) }
    }

    private func block(from line: String) -> [[String: Any]] {
        let decorated = stripBlockColor(from: line)
        let trimmed = decorated.text

        if trimmed == "---" || trimmed == "***" || trimmed == "___" {
            return [dividerBlock()]
        }

        if let heading = heading(from: trimmed) {
            return [headingBlock(level: min(max(heading.level, 1), 3), text: heading.text, color: decorated.color)]
        }

        if trimmed.hasPrefix("- [ ] ") || trimmed.hasPrefix("- [x] ") || trimmed.hasPrefix("- [X] ") {
            let checked = trimmed.hasPrefix("- [x] ") || trimmed.hasPrefix("- [X] ")
            let content = String(trimmed.dropFirst(6)).trimmingCharacters(in: .whitespaces)
            return [textBlock(type: "to_do", key: "to_do", text: content, color: decorated.color, extra: ["checked": checked])]
        }

        if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") || trimmed.hasPrefix("+ ") {
            return [textBlock(type: "bulleted_list_item", key: "bulleted_list_item", text: String(trimmed.dropFirst(2)), color: decorated.color)]
        }

        if let numbered = numberedListText(from: trimmed) {
            return [textBlock(type: "numbered_list_item", key: "numbered_list_item", text: numbered, color: decorated.color)]
        }

        if trimmed.hasPrefix("> ") {
            return [textBlock(type: "quote", key: "quote", text: String(trimmed.dropFirst(2)), color: decorated.color)]
        }

        return [paragraphBlock(trimmed, color: decorated.color)]
    }

    private func paragraphBlock(_ text: String, color: String = "default") -> [String: Any] {
        textBlock(type: "paragraph", key: "paragraph", text: text, color: color)
    }

    private func headingBlock(level: Int, text: String, color: String = "default") -> [String: Any] {
        let key = "heading_\(level)"
        return [
            "type": key,
            key: [
                "rich_text": richText(text),
                "color": normalizedColor(color),
                "is_toggleable": false
            ]
        ]
    }

    private func textBlock(type: String, key: String, text: String, color: String = "default", extra: [String: Any] = [:]) -> [String: Any] {
        var payload: [String: Any] = [
            "rich_text": richText(text),
            "color": normalizedColor(color)
        ]
        for (key, value) in extra {
            payload[key] = value
        }
        return [
            "type": type,
            key: payload
        ]
    }

    private func dividerBlock() -> [String: Any] {
        [
            "type": "divider",
            "divider": [:]
        ]
    }

    private func codeBlock(_ text: String, language: String) -> [String: Any] {
        [
            "type": "code",
            "code": [
                "caption": [],
                "rich_text": plainRichText(text),
                "language": normalizedCodeLanguage(language)
            ]
        ]
    }

    private func equationBlock(_ expression: String) -> [String: Any] {
        [
            "type": "equation",
            "equation": [
                "expression": expression.trimmingCharacters(in: .whitespacesAndNewlines)
            ]
        ]
    }

    private func calloutBlock(lines: [String], attributes: [String: String]) -> [String: Any] {
        let nonEmptyLines = lines.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        let title = nonEmptyLines.first ?? "Note"
        let childMarkdown = nonEmptyLines.dropFirst().joined(separator: "\n")
        var payload: [String: Any] = [
            "rich_text": richText(title),
            "icon": [
                "type": "emoji",
                "emoji": attributes["icon"] ?? "💡"
            ],
            "color": normalizedColor(attributes["color"] ?? "blue_bg")
        ]

        let children = blocks(from: childMarkdown)
        if !children.isEmpty {
            payload["children"] = children
        }

        return [
            "type": "callout",
            "callout": payload
        ]
    }

    private func tableBlock(from lines: [String]) -> [String: Any]? {
        var rows = lines.map(parseTableRow).filter { !$0.isEmpty }
        guard rows.count >= 2 else {
            return nil
        }

        let hasColumnHeader = rows.indices.contains(1) && rows[1].allSatisfy(isMarkdownTableSeparator)
        if hasColumnHeader {
            rows.remove(at: 1)
        }

        guard let width = rows.map(\.count).max(), width > 0 else {
            return nil
        }

        let children = rows.map { row -> [String: Any] in
            let padded = row + Array(repeating: "", count: max(0, width - row.count))
            return [
                "type": "table_row",
                "table_row": [
                    "cells": padded.prefix(width).map { richText($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
                ]
            ]
        }

        return [
            "type": "table",
            "table": [
                "table_width": width,
                "has_column_header": hasColumnHeader,
                "has_row_header": false,
                "children": children
            ]
        ]
    }

    private func parseInline(_ text: String, annotations: InlineAnnotations, link: String? = nil) -> [[String: Any]] {
        var result: [[String: Any]] = []
        var buffer = ""
        var index = text.startIndex

        func flushBuffer() {
            guard !buffer.isEmpty else { return }
            for chunk in splitText(buffer) {
                result.append(textObject(content: chunk, annotations: annotations, link: link))
            }
            buffer.removeAll()
        }

        while index < text.endIndex {
            if hasPrefix("\\", in: text, at: index) {
                let next = text.index(after: index)
                if next < text.endIndex {
                    buffer.append(text[next])
                    index = text.index(after: next)
                } else {
                    buffer.append(text[index])
                    index = next
                }
                continue
            }

            if hasPrefix("<br>", in: text, at: index) {
                buffer.append("\n")
                index = text.index(index, offsetBy: 4)
                continue
            }

            if hasPrefix("<span", in: text, at: index),
               let tagEnd = text[index...].firstIndex(of: ">"),
               let closeStart = text.range(of: "</span>", range: tagEnd..<text.endIndex)?.lowerBound {
                flushBuffer()
                let tag = String(text[index...tagEnd])
                let inner = String(text[text.index(after: tagEnd)..<closeStart])
                let attrs = attributes(from: tag)
                var nested = annotations
                if let color = attrs["color"] {
                    nested.color = normalizedColor(color)
                }
                if attrs["underline"] == "true" {
                    nested.underline = true
                }
                result.append(contentsOf: parseInline(inner, annotations: nested, link: link))
                index = text.index(closeStart, offsetBy: "</span>".count)
                continue
            }

            if hasPrefix("**", in: text, at: index),
               let close = closingMarker("**", in: text, from: text.index(index, offsetBy: 2)) {
                flushBuffer()
                var nested = annotations
                nested.bold = true
                result.append(contentsOf: parseInline(String(text[text.index(index, offsetBy: 2)..<close]), annotations: nested, link: link))
                index = text.index(close, offsetBy: 2)
                continue
            }

            if hasPrefix("~~", in: text, at: index),
               let close = closingMarker("~~", in: text, from: text.index(index, offsetBy: 2)) {
                flushBuffer()
                var nested = annotations
                nested.strikethrough = true
                result.append(contentsOf: parseInline(String(text[text.index(index, offsetBy: 2)..<close]), annotations: nested, link: link))
                index = text.index(close, offsetBy: 2)
                continue
            }

            if hasPrefix("`", in: text, at: index),
               let close = closingMarker("`", in: text, from: text.index(after: index)) {
                flushBuffer()
                var nested = annotations
                nested.code = true
                for chunk in splitText(String(text[text.index(after: index)..<close])) {
                    result.append(textObject(content: chunk, annotations: nested, link: link))
                }
                index = text.index(after: close)
                continue
            }

            if hasPrefix("[", in: text, at: index),
               let labelEnd = text[index...].firstIndex(of: "]"),
               labelEnd < text.index(before: text.endIndex),
               text[text.index(after: labelEnd)] == "(",
               let urlEnd = text[text.index(labelEnd, offsetBy: 2)...].firstIndex(of: ")") {
                flushBuffer()
                let label = String(text[text.index(after: index)..<labelEnd])
                let url = String(text[text.index(labelEnd, offsetBy: 2)..<urlEnd])
                result.append(contentsOf: parseInline(label, annotations: annotations, link: url))
                index = text.index(after: urlEnd)
                continue
            }

            if hasPrefix("$", in: text, at: index),
               !hasPrefix("$$", in: text, at: index),
               let close = closingMarker("$", in: text, from: text.index(after: index)) {
                let expression = String(text[text.index(after: index)..<close]).trimmingCharacters(in: .whitespacesAndNewlines)
                if !expression.isEmpty {
                    flushBuffer()
                    result.append(equationRichText(expression: expression, annotations: annotations))
                    index = text.index(after: close)
                    continue
                }
            }

            if hasPrefix("*", in: text, at: index),
               !hasPrefix("**", in: text, at: index),
               let close = closingMarker("*", in: text, from: text.index(after: index)) {
                flushBuffer()
                var nested = annotations
                nested.italic = true
                result.append(contentsOf: parseInline(String(text[text.index(after: index)..<close]), annotations: nested, link: link))
                index = text.index(after: close)
                continue
            }

            buffer.append(text[index])
            index = text.index(after: index)
        }

        flushBuffer()
        return result
    }

    private func textObject(content: String, annotations: InlineAnnotations, link: String? = nil) -> [String: Any] {
        var textPayload: [String: Any] = ["content": content]
        if let link, !link.isEmpty {
            textPayload["link"] = ["url": link]
        }
        return [
            "type": "text",
            "text": textPayload,
            "annotations": annotations.dictionary
        ]
    }

    private func equationRichText(expression: String, annotations: InlineAnnotations) -> [String: Any] {
        [
            "type": "equation",
            "equation": [
                "expression": expression
            ],
            "annotations": annotations.dictionary
        ]
    }

    private func splitText(_ text: String, limit: Int = 1_900) -> [String] {
        guard !text.isEmpty else {
            return []
        }

        var chunks: [String] = []
        var start = text.startIndex
        while start < text.endIndex {
            let end = text.index(start, offsetBy: limit, limitedBy: text.endIndex) ?? text.endIndex
            chunks.append(String(text[start..<end]))
            start = end
        }
        return chunks
    }

    private func heading(from line: String) -> (level: Int, text: String)? {
        guard line.hasPrefix("#") else {
            return nil
        }
        let level = line.prefix { $0 == "#" }.count
        guard level > 0, line.dropFirst(level).first == " " else {
            return nil
        }
        let text = line.dropFirst(level).trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : (level, String(text))
    }

    private func numberedListText(from line: String) -> String? {
        guard let dotIndex = line.firstIndex(of: ".") else {
            return nil
        }

        let prefix = line[..<dotIndex]
        guard !prefix.isEmpty, prefix.allSatisfy(\.isNumber) else {
            return nil
        }

        let afterDot = line.index(after: dotIndex)
        guard afterDot < line.endIndex, line[afterDot] == " " else {
            return nil
        }

        return String(line[line.index(after: afterDot)...])
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func isTableLine(_ line: String) -> Bool {
        line.contains("|") && (line.first == "|" || line.contains(" | "))
    }

    private func parseTableRow(_ line: String) -> [String] {
        var trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.first == "|" {
            trimmed.removeFirst()
        }
        if trimmed.last == "|" {
            trimmed.removeLast()
        }
        return trimmed.components(separatedBy: "|").map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    private func isMarkdownTableSeparator(_ cell: String) -> Bool {
        let trimmed = cell.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed.allSatisfy { character in
            character == "-" || character == ":" || character == " "
        }
    }

    private func stripBlockColor(from line: String) -> (text: String, color: String) {
        let pattern = #"\s*\{color=\"([A-Za-z_]+)\"\}\s*$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..<line.endIndex, in: line)),
              let matchRange = Range(match.range, in: line),
              let colorRange = Range(match.range(at: 1), in: line) else {
            return (line, "default")
        }

        let text = String(line[..<matchRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        return (text, normalizedColor(String(line[colorRange])))
    }

    private func attributes(from tag: String) -> [String: String] {
        let pattern = #"([A-Za-z-]+)=\"([^\"]*)\""#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return [:]
        }
        let matches = regex.matches(in: tag, range: NSRange(tag.startIndex..<tag.endIndex, in: tag))
        var attributes: [String: String] = [:]
        for match in matches {
            guard let keyRange = Range(match.range(at: 1), in: tag),
                  let valueRange = Range(match.range(at: 2), in: tag) else {
                continue
            }
            attributes[String(tag[keyRange])] = String(tag[valueRange])
        }
        return attributes
    }

    private func inlineCalloutBody(from line: String) -> String? {
        guard let tagEnd = line.firstIndex(of: ">"),
              let closeRange = line.range(of: "</callout>") else {
            return nil
        }
        let body = line[line.index(after: tagEnd)..<closeRange.lowerBound]
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return body.isEmpty ? nil : String(body)
    }

    private func strippingOneLeadingTab(_ line: String) -> String {
        if line.hasPrefix("\t") {
            return String(line.dropFirst())
        }
        return line
    }

    private func closingMarker(_ marker: String, in text: String, from start: String.Index) -> String.Index? {
        var index = start
        while index < text.endIndex {
            if hasPrefix(marker, in: text, at: index),
               !isEscaped(index, in: text) {
                return index
            }
            index = text.index(after: index)
        }
        return nil
    }

    private func hasPrefix(_ prefix: String, in text: String, at index: String.Index) -> Bool {
        text[index...].hasPrefix(prefix)
    }

    private func isEscaped(_ index: String.Index, in text: String) -> Bool {
        guard index > text.startIndex else {
            return false
        }
        return text[text.index(before: index)] == "\\"
    }

    private func normalizedColor(_ color: String) -> String {
        let normalized = color.trimmingCharacters(in: .whitespacesAndNewlines)
        return validColors.contains(normalized) ? normalized : "default"
    }

    private func normalizedCodeLanguage(_ language: String) -> String {
        let normalized = language.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else {
            return "plain text"
        }

        switch normalized {
        case "text", "txt", "plain":
            return "plain text"
        case "js":
            return "javascript"
        case "ts":
            return "typescript"
        case "py":
            return "python"
        case "sh", "shell", "zsh":
            return "bash"
        case "yml":
            return "yaml"
        case "md":
            return "markdown"
        case "asm", "assembly", "armasm":
            return "plain text"
        default:
            return validCodeLanguages.contains(normalized) ? normalized : "plain text"
        }
    }

    private var validColors: Set<String> {
        [
            "default",
            "gray", "brown", "orange", "yellow", "green", "blue", "purple", "pink", "red",
            "gray_bg", "brown_bg", "orange_bg", "yellow_bg", "green_bg", "blue_bg", "purple_bg", "pink_bg", "red_bg"
        ]
    }

    private var validCodeLanguages: Set<String> {
        [
            "plain text", "abap", "arduino", "bash", "basic", "c", "clojure", "coffeescript", "c++", "c#", "css",
            "dart", "diff", "docker", "elixir", "elm", "erlang", "flow", "fortran", "f#", "gherkin", "glsl",
            "go", "graphql", "groovy", "haskell", "html", "java", "javascript", "json", "julia", "kotlin",
            "latex", "less", "lisp", "livescript", "lua", "makefile", "markdown", "markup", "matlab", "mermaid",
            "nix", "objective-c", "ocaml", "pascal", "perl", "php", "powershell", "prolog", "protobuf", "python",
            "r", "reason", "ruby", "rust", "sass", "scala", "scheme", "scss", "shell", "sql", "swift", "typescript",
            "vb.net", "verilog", "vhdl", "visual basic", "webassembly", "xml", "yaml"
        ]
    }
}

private struct InlineAnnotations {
    var bold = false
    var italic = false
    var strikethrough = false
    var underline = false
    var code = false
    var color = "default"

    var dictionary: [String: Any] {
        [
            "bold": bold,
            "italic": italic,
            "strikethrough": strikethrough,
            "underline": underline,
            "code": code,
            "color": color
        ]
    }
}
