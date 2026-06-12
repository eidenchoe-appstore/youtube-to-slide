import Foundation

enum OpenRouterError: LocalizedError {
    case missingAPIKey
    case invalidImageData(URL)
    case emptyResponse
    case requestFailed(Int, String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Enter and save an OpenRouter API key first."
        case let .invalidImageData(url):
            return "Could not read slide image for OpenRouter: \(url.lastPathComponent)."
        case .emptyResponse:
            return "OpenRouter returned an empty response."
        case let .requestFailed(statusCode, message):
            return "OpenRouter request failed with HTTP \(statusCode): \(message)"
        }
    }
}

struct OpenRouterClient {
    var apiKey: String
    var modelIDs: [String]

    init(apiKey: String, modelID: String) {
        self.apiKey = apiKey
        self.modelIDs = [modelID]
    }

    init(apiKey: String, modelIDs: [String]) {
        self.apiKey = apiKey
        var uniqueModelIDs: [String] = []
        for modelID in modelIDs
        where OpenRouterStudyModel.isUsableModelID(modelID) {
            let trimmed = OpenRouterStudyModel.sanitizedModelID(modelID)
            if !uniqueModelIDs.contains(trimmed) {
                uniqueModelIDs.append(trimmed)
            }
        }
        self.modelIDs = uniqueModelIDs.isEmpty ? [OpenRouterStudyModel.defaultPrimaryID] : uniqueModelIDs
    }

    func generateStudyNote(slide: SlideFrame, lectureTitle: String) async throws -> SlideStudyNote {
        let prompt = """
        You are a lecture study-note assistant. Analyze the attached lecture slide image.

        Write in Korean by default, while preserving important English technical terms.
        Return concise structured study-note text in Notion-friendly enhanced Markdown.
        You must infer a study-friendly slide title from the image. The first non-empty line must be:
        # {inferred slide title}

        Formatting rules:
        - Use only #, ##, and ### headings.
        - Use "- " for bullet lists.
        - Use numbered lists only when sequence matters.
        - Use **bold** for key terms and definitions.
        - Use `inline code` for registers, flags, instructions, binary values, hex values, and short formulas that are code-like.
        - Use $...$ for inline math such as $2^n$ or $34 \\bmod 32 = 2$ when math notation helps.
        - Use fenced code blocks only for real code or aligned binary arithmetic.
        - Use > quote blocks for important quoted statements.
        - Use <callout icon="⚠️" color="yellow_background"> for common mistakes or exam warnings when useful.
        - Use <span color="red">text</span> sparingly for genuinely critical warnings.
        - Use simple Markdown tables only when the slide contains a clear comparison table.
        - Do not include image markdown; the app uploads slide images separately.
        - Do not use footnotes, internal anchor links, definition lists, Mermaid, or complex tables.
        - Do not repeat the same note twice. Return one complete note only.
        - Keep each section useful for a student trying to understand the slide, not just OCR text.

        Use this exact structure:
        # {inferred slide title}

        ## 핵심 요약
        - 3-5 bullets

        ## 슬라이드 내용 해설
        - Explain the concepts in study-friendly language so a student can understand what this slide is teaching.
        - Include necessary background, definitions, and causal relationships when they are visible or strongly implied.

        ## 이미지/텍스트에서 읽힌 주요 정보
        - OCR-like key terms, equations, code, chart labels, or diagram elements.

        ## 공부할 때 주의할 점
        - Common misunderstanding, exam point, or practical interpretation.

        ## 복습 질문
        - 3 questions a student should answer.

        Lecture title: \(lectureTitle)
        Slide index: \(slide.index)
        Timestamp: \(AppFormatters.timestamp(slide.timestampSec))
        """

        let response = try await sendVisionRequestWithFallback(prompt: prompt, imageURLs: [slide.fileURL])
        return SlideStudyNote(
            slideIndex: slide.index,
            timestampSec: slide.timestampSec,
            markdown: response.content,
            modelID: response.modelID,
            generatedAt: Date()
        )
    }

    func answerQuestion(
        question: String,
        job: ExtractionJob,
        selectedSlide: SlideFrame?,
        scope: StudyChatScope
    ) async throws -> String {
        var prompt = """
        You are a Korean study assistant for lecture slides.
        Answer clearly in Korean. Use Notion-friendly enhanced Markdown. Be concrete and refer to slide numbers when possible.
        Use only #, ##, ### headings, "- " bullets, numbered lists, simple tables, fenced code blocks, blockquotes, inline code, $inline math$, <callout>, and <span color="..."> when useful.
        Avoid image markdown, footnotes, internal anchor links, Mermaid, and complex tables.

        Lecture title: \(job.title)
        User question: \(question)
        """

        var imageURLs: [URL] = []

        switch scope {
        case .selectedSlide:
            if let selectedSlide {
                prompt += "\nFocus on selected slide #\(selectedSlide.index) at \(AppFormatters.timestamp(selectedSlide.timestampSec))."
                if let note = job.studyNotes[selectedSlide.index] {
                    prompt += "\nExisting note for this slide:\n\(note.markdown)"
                }
                imageURLs = [selectedSlide.fileURL]
            }
        case .allSlides:
            let notes = job.studyNotes.values
                .sorted { $0.slideIndex < $1.slideIndex }
                .map { "### Slide \($0.slideIndex)\n\($0.markdown)" }
                .joined(separator: "\n\n")

            if notes.isEmpty {
                prompt += "\nNo generated study notes are available yet. Use the attached slide images to answer."
                imageURLs = Array(job.slides.prefix(8).map(\.fileURL))
            } else {
                prompt += "\nUse these generated study notes as the primary context:\n\(notes)"
            }
        }

        return try await sendVisionRequestWithFallback(prompt: prompt, imageURLs: imageURLs).content
    }

    private func sendVisionRequestWithFallback(prompt: String, imageURLs: [URL]) async throws -> (content: String, modelID: String) {
        var lastError: Error?

        for modelID in modelIDs {
            do {
                let content = try await sendVisionRequest(prompt: prompt, imageURLs: imageURLs, modelID: modelID)
                return (content, modelID)
            } catch let openRouterError as OpenRouterError {
                if case .invalidImageData = openRouterError {
                    throw openRouterError
                }
                lastError = openRouterError
            } catch {
                lastError = error
            }
        }

        throw lastError ?? OpenRouterError.emptyResponse
    }

    private func sendVisionRequest(prompt: String, imageURLs: [URL], modelID: String) async throws -> String {
        var request = URLRequest(url: URL(string: "https://openrouter.ai/api/v1/chat/completions")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("https://github.com/eidenchoe-appstore/youtube-to-slide", forHTTPHeaderField: "HTTP-Referer")
        request.setValue("YouTube to Slide", forHTTPHeaderField: "X-Title")

        var content: [[String: Any]] = [
            [
                "type": "text",
                "text": prompt
            ]
        ]

        for imageURL in imageURLs {
            content.append([
                "type": "image_url",
                "image_url": [
                    "url": try dataURL(for: imageURL)
                ]
            ])
        }

        let body: [String: Any] = [
            "model": modelID,
            "messages": [
                [
                    "role": "user",
                    "content": content
                ]
            ],
            "temperature": 0.2
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenRouterError.emptyResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "No error body"
            throw OpenRouterError.requestFailed(httpResponse.statusCode, message)
        }

        let decoded = try JSONDecoder().decode(OpenRouterChatResponse.self, from: data)
        guard let content = decoded.choices.first?.message.content.trimmingCharacters(in: .whitespacesAndNewlines),
              !content.isEmpty else {
            throw OpenRouterError.emptyResponse
        }

        return content
    }

    private func dataURL(for imageURL: URL) throws -> String {
        guard let data = try? Data(contentsOf: imageURL) else {
            throw OpenRouterError.invalidImageData(imageURL)
        }

        let mimeType = imageURL.pathExtension.lowercased() == "jpg" || imageURL.pathExtension.lowercased() == "jpeg"
            ? "image/jpeg"
            : "image/png"
        return "data:\(mimeType);base64,\(data.base64EncodedString())"
    }
}

private struct OpenRouterChatResponse: Decodable {
    var choices: [Choice]

    struct Choice: Decodable {
        var message: Message
    }

    struct Message: Decodable {
        var content: String
    }
}
