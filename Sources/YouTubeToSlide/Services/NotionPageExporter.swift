import Foundation

enum NotionExportError: LocalizedError {
    case noSlides
    case invalidParentPageURL
    case invalidImageData(URL)
    case uploadTooLarge(URL, Int64)
    case requestFailed(Int, String)
    case unexpectedResponse(String)

    var errorDescription: String? {
        switch self {
        case .noSlides:
            return "Extract slides before sending a Notion page."
        case .invalidParentPageURL:
            return "Enter a valid Notion parent page URL or page ID."
        case let .invalidImageData(url):
            return "Could not read slide image for Notion: \(url.lastPathComponent)."
        case let .uploadTooLarge(url, size):
            return "\(url.lastPathComponent) is too large for single-part Notion upload (\(size) bytes). Reduce output resolution or use a smaller slide image."
        case let .requestFailed(statusCode, message):
            return "Notion request failed with HTTP \(statusCode): \(message)"
        case let .unexpectedResponse(message):
            return "Notion returned an unexpected response: \(message)"
        }
    }
}

struct NotionExportResult {
    var pageID: String
    var pageURL: URL
}

struct NotionParentPageIDParser {
    static func parse(_ input: String) -> String? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }

        let decoded = trimmed.removingPercentEncoding ?? trimmed
        if let dashed = lastMatch(
            in: decoded,
            pattern: #"[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}"#
        ) {
            return dashed.lowercased()
        }

        guard let compact = lastMatch(in: decoded, pattern: #"[0-9a-fA-F]{32}"#) else {
            return nil
        }

        let lowercased = compact.lowercased()
        let first = lowercased.index(lowercased.startIndex, offsetBy: 8)
        let second = lowercased.index(first, offsetBy: 4)
        let third = lowercased.index(second, offsetBy: 4)
        let fourth = lowercased.index(third, offsetBy: 4)

        return [
            String(lowercased[..<first]),
            String(lowercased[first..<second]),
            String(lowercased[second..<third]),
            String(lowercased[third..<fourth]),
            String(lowercased[fourth...])
        ].joined(separator: "-")
    }

    private static func lastMatch(in input: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }

        let range = NSRange(input.startIndex..<input.endIndex, in: input)
        return regex.matches(in: input, range: range).last.flatMap { match in
            guard let matchRange = Range(match.range, in: input) else {
                return nil
            }
            return String(input[matchRange])
        }
    }
}

struct NotionPageExporter {
    private let apiKey: String
    private let apiVersion = "2026-03-11"
    private let maxSinglePartUploadBytes: Int64 = 20 * 1024 * 1024

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    func export(job: ExtractionJob, parentPageURL: String) async throws -> NotionExportResult {
        guard !job.slides.isEmpty else {
            throw NotionExportError.noSlides
        }

        guard let parentPageID = NotionParentPageIDParser.parse(parentPageURL) else {
            throw NotionExportError.invalidParentPageURL
        }

        let title = notionTitle(for: job)
        let createdPage = try await createPage(parentPageID: parentPageID, title: title)
        try await appendBlocks(createdPage.id, blocks: introBlocks(for: job, title: title))

        for slide in job.slides.sorted(by: { $0.index < $1.index }) {
            try Task.checkCancellation()
            let fileUploadID = try await uploadImage(slide: slide)
            try await appendBlocks(createdPage.id, blocks: slideBlocks(for: slide, job: job, fileUploadID: fileUploadID))
        }

        guard let pageURL = URL(string: createdPage.url) else {
            throw NotionExportError.unexpectedResponse("Created page did not include a valid URL.")
        }

        return NotionExportResult(pageID: createdPage.id, pageURL: pageURL)
    }

    private func notionTitle(for job: ExtractionJob) -> String {
        if job.inputType == .localVideo,
           let sourceURL = job.sourceURL {
            let filename = sourceURL.deletingPathExtension().lastPathComponent
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !filename.isEmpty {
                return filename
            }
        }

        return job.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Lecture Notes" : job.title
    }

    private func createPage(parentPageID: String, title: String) async throws -> NotionPageResponse {
        let body: [String: Any] = [
            "parent": [
                "type": "page_id",
                "page_id": parentPageID
            ],
            "properties": [
                "title": [
                    "title": richText(title)
                ]
            ]
        ]

        let data = try await jsonRequest(path: "/v1/pages", method: "POST", body: body)
        return try decode(NotionPageResponse.self, from: data)
    }

    private func uploadImage(slide: SlideFrame) async throws -> String {
        let fileURL = slide.fileURL
        let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path)
        if let size = attributes?[.size] as? NSNumber,
           size.int64Value > maxSinglePartUploadBytes {
            throw NotionExportError.uploadTooLarge(fileURL, size.int64Value)
        }

        guard let imageData = try? Data(contentsOf: fileURL) else {
            throw NotionExportError.invalidImageData(fileURL)
        }

        let filename = fileURL.lastPathComponent
        let contentType = mimeType(for: fileURL)
        let upload = try await createFileUpload(filename: filename, contentType: contentType)
        let sent = try await sendFileUpload(uploadID: upload.id, filename: filename, contentType: contentType, data: imageData)

        guard sent.status == "uploaded" else {
            throw NotionExportError.unexpectedResponse("File upload \(sent.id) status is \(sent.status).")
        }

        return sent.id
    }

    private func createFileUpload(filename: String, contentType: String) async throws -> NotionFileUploadResponse {
        let body: [String: Any] = [
            "mode": "single_part",
            "filename": filename,
            "content_type": contentType
        ]

        let data = try await jsonRequest(path: "/v1/file_uploads", method: "POST", body: body)
        return try decode(NotionFileUploadResponse.self, from: data)
    }

    private func sendFileUpload(uploadID: String, filename: String, contentType: String, data: Data) async throws -> NotionFileUploadResponse {
        let boundary = "Boundary-\(UUID().uuidString)"
        var body = Data()
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n")
        body.append("Content-Type: \(contentType)\r\n\r\n")
        body.append(data)
        body.append("\r\n--\(boundary)--\r\n")

        var request = URLRequest(url: notionURL(path: "/v1/file_uploads/\(uploadID)/send"))
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue(apiVersion, forHTTPHeaderField: "Notion-Version")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = body

        let responseData = try await perform(request)
        return try decode(NotionFileUploadResponse.self, from: responseData)
    }

    private func appendBlocks(_ blockID: String, blocks: [[String: Any]]) async throws {
        for chunk in blocks.chunked(into: 80) where !chunk.isEmpty {
            let body: [String: Any] = ["children": chunk]
            _ = try await jsonRequest(path: "/v1/blocks/\(blockID)/children", method: "PATCH", body: body)
        }
    }

    private func introBlocks(for job: ExtractionJob, title: String) -> [[String: Any]] {
        let generatedAt = ISO8601DateFormatter().string(from: Date())
        return [
            paragraphBlock("Source: \(job.source)"),
            paragraphBlock("Generated: \(generatedAt)"),
            paragraphBlock("Slides: \(job.slides.count)"),
            dividerBlock()
        ]
    }

    private func slideBlocks(for slide: SlideFrame, job: ExtractionJob, fileUploadID: String) -> [[String: Any]] {
        let note = studyNoteTitleAndBody(job.studyNotes[slide.index]?.markdown)
        let slideTitle = note.title ?? "Slide \(slide.index)"

        var blocks: [[String: Any]] = [
            headingBlock(level: 2, text: "Slide \(slide.index): \(slideTitle)"),
            paragraphBlock("Timestamp: \(AppFormatters.timestamp(slide.timestampSec))"),
            imageBlock(fileUploadID: fileUploadID, caption: "Slide \(slide.index) · \(AppFormatters.timestamp(slide.timestampSec))")
        ]

        if note.body.isEmpty {
            blocks.append(paragraphBlock("No study note generated for this slide yet."))
        } else {
            blocks.append(contentsOf: markdownBlocks(from: note.body))
        }

        blocks.append(dividerBlock())
        return blocks
    }

    private func markdownBlocks(from markdown: String) -> [[String: Any]] {
        var blocks: [[String: Any]] = []
        var codeLines: [String] = []
        var isInCodeBlock = false
        var tableLines: [String] = []

        func flushTable() {
            guard !tableLines.isEmpty else { return }
            blocks.append(codeBlock(tableLines.joined(separator: "\n"), language: "markdown"))
            tableLines.removeAll()
        }

        func appendTextBlock(type: String, key: String, text: String, extra: [String: Any] = [:]) {
            for chunk in splitText(text) {
                var payload: [String: Any] = [
                    "rich_text": richText(chunk),
                    "color": "default"
                ]
                for (key, value) in extra {
                    payload[key] = value
                }
                blocks.append([
                    "type": type,
                    key: payload
                ])
            }
        }

        for rawLine in markdown
            .replacingOccurrences(of: "\r\n", with: "\n")
            .components(separatedBy: "\n") {
            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("```") {
                flushTable()
                if isInCodeBlock {
                    blocks.append(codeBlock(codeLines.joined(separator: "\n"), language: "plain text"))
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

            if trimmed.isEmpty {
                flushTable()
                continue
            }

            if trimmed.contains("|"),
               trimmed.first == "|" || trimmed.contains(" | ") {
                tableLines.append(rawLine)
                continue
            }

            flushTable()

            if trimmed == "---" || trimmed == "***" || trimmed == "___" {
                blocks.append(dividerBlock())
            } else if let heading = headingText(from: trimmed) {
                blocks.append(headingBlock(level: 3, text: heading))
            } else if trimmed.hasPrefix("- [ ] ") || trimmed.hasPrefix("- [x] ") || trimmed.hasPrefix("- [X] ") {
                let checked = trimmed.hasPrefix("- [x] ") || trimmed.hasPrefix("- [X] ")
                let content = String(trimmed.dropFirst(6)).trimmingCharacters(in: .whitespaces)
                appendTextBlock(type: "to_do", key: "to_do", text: content, extra: ["checked": checked])
            } else if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") || trimmed.hasPrefix("+ ") {
                appendTextBlock(type: "bulleted_list_item", key: "bulleted_list_item", text: String(trimmed.dropFirst(2)))
            } else if let numbered = numberedListText(from: trimmed) {
                appendTextBlock(type: "numbered_list_item", key: "numbered_list_item", text: numbered)
            } else if trimmed.hasPrefix("> ") {
                appendTextBlock(type: "quote", key: "quote", text: String(trimmed.dropFirst(2)))
            } else {
                appendTextBlock(type: "paragraph", key: "paragraph", text: trimmed)
            }
        }

        if isInCodeBlock || !codeLines.isEmpty {
            blocks.append(codeBlock(codeLines.joined(separator: "\n"), language: "plain text"))
        }
        flushTable()

        return blocks
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

    private func headingText(from line: String) -> String? {
        guard line.hasPrefix("#") else {
            return nil
        }

        let text = line.drop { $0 == "#" || $0 == " " }
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : String(text)
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

    private func headingBlock(level: Int, text: String) -> [String: Any] {
        let key = "heading_\(min(max(level, 1), 3))"
        return [
            "type": key,
            key: [
                "rich_text": richText(text),
                "color": "default",
                "is_toggleable": false
            ]
        ]
    }

    private func paragraphBlock(_ text: String) -> [String: Any] {
        [
            "type": "paragraph",
            "paragraph": [
                "rich_text": richText(text),
                "color": "default"
            ]
        ]
    }

    private func dividerBlock() -> [String: Any] {
        [
            "type": "divider",
            "divider": [:]
        ]
    }

    private func imageBlock(fileUploadID: String, caption: String) -> [String: Any] {
        [
            "type": "image",
            "image": [
                "caption": richText(caption),
                "type": "file_upload",
                "file_upload": [
                    "id": fileUploadID
                ]
            ]
        ]
    }

    private func codeBlock(_ text: String, language: String) -> [String: Any] {
        [
            "type": "code",
            "code": [
                "caption": [],
                "rich_text": richText(text),
                "language": language
            ]
        ]
    }

    private func richText(_ text: String) -> [[String: Any]] {
        splitText(text).map { chunk in
            [
                "type": "text",
                "text": [
                    "content": chunk
                ]
            ]
        }
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

    private func mimeType(for url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "jpg", "jpeg":
            return "image/jpeg"
        case "gif":
            return "image/gif"
        case "webp":
            return "image/webp"
        default:
            return "image/png"
        }
    }

    private func jsonRequest(path: String, method: String, body: [String: Any]) async throws -> Data {
        var request = URLRequest(url: notionURL(path: path))
        request.httpMethod = method
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue(apiVersion, forHTTPHeaderField: "Notion-Version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return try await perform(request)
    }

    private func perform(_ request: URLRequest) async throws -> Data {
        var lastError: Error?

        for attempt in 0..<3 {
            try Task.checkCancellation()
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NotionExportError.unexpectedResponse("Missing HTTP response.")
            }

            if (200..<300).contains(httpResponse.statusCode) {
                try await throttle()
                return data
            }

            let message = notionErrorMessage(from: data)
            if shouldRetry(statusCode: httpResponse.statusCode), attempt < 2 {
                let retryAfter = retryAfterSeconds(from: httpResponse) ?? Double(attempt + 1)
                lastError = NotionExportError.requestFailed(httpResponse.statusCode, message)
                try await Task.sleep(nanoseconds: UInt64(retryAfter * 1_000_000_000))
                continue
            }

            throw NotionExportError.requestFailed(httpResponse.statusCode, message)
        }

        throw lastError ?? NotionExportError.unexpectedResponse("Request did not complete.")
    }

    private func shouldRetry(statusCode: Int) -> Bool {
        statusCode == 429 || [500, 503, 504, 529].contains(statusCode)
    }

    private func retryAfterSeconds(from response: HTTPURLResponse) -> Double? {
        guard let value = response.value(forHTTPHeaderField: "Retry-After") else {
            return nil
        }
        return Double(value)
    }

    private func notionErrorMessage(from data: Data) -> String {
        if let error = try? JSONDecoder().decode(NotionErrorResponse.self, from: data) {
            return [error.code, error.message].compactMap { $0 }.joined(separator: ": ")
        }
        return String(data: data, encoding: .utf8) ?? "No response body"
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            throw NotionExportError.unexpectedResponse(error.localizedDescription)
        }
    }

    private func notionURL(path: String) -> URL {
        URL(string: "https://api.notion.com\(path)")!
    }

    private func throttle() async throws {
        try await Task.sleep(nanoseconds: 250_000_000)
    }
}

private struct NotionPageResponse: Decodable {
    var id: String
    var url: String
}

private struct NotionFileUploadResponse: Decodable {
    var id: String
    var status: String
}

private struct NotionErrorResponse: Decodable {
    var code: String?
    var message: String?
}

private extension Data {
    mutating func append(_ string: String) {
        append(Data(string.utf8))
    }
}

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else {
            return [self]
        }

        var chunks: [[Element]] = []
        var index = startIndex
        while index < endIndex {
            let end = self.index(index, offsetBy: size, limitedBy: endIndex) ?? endIndex
            chunks.append(Array(self[index..<end]))
            index = end
        }
        return chunks
    }
}
