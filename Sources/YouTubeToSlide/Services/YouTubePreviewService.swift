import Foundation

enum YouTubePreviewError: LocalizedError {
    case unsupportedURL
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .unsupportedURL:
            return "Enter a valid YouTube URL."
        case .invalidResponse:
            return "Could not load the YouTube preview."
        }
    }
}

struct YouTubePreviewService {
    func preview(for rawURL: String) async throws -> YouTubePreview {
        let trimmed = rawURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed),
              YouTubeURLParser.isLikelyYouTubeURL(url) else {
            throw YouTubePreviewError.unsupportedURL
        }

        let encodedURL = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? trimmed
        let endpoint = URL(string: "https://www.youtube.com/oembed?format=json&url=\(encodedURL)")!

        if let (data, response) = try? await URLSession.shared.data(from: endpoint),
           let httpResponse = response as? HTTPURLResponse,
           (200..<300).contains(httpResponse.statusCode),
           let payload = try? JSONDecoder().decode(OEmbedPayload.self, from: data) {
            return YouTubePreview(
                sourceURL: trimmed,
                title: FileNameSanitizer.sanitize(payload.title, fallback: "YouTube Video"),
                authorName: payload.authorName,
                thumbnailURL: URL(string: payload.thumbnailURL ?? ""),
                videoID: YouTubeURLParser.videoID(from: url)
            )
        }

        if let videoID = YouTubeURLParser.videoID(from: url) {
            return YouTubePreview(
                sourceURL: trimmed,
                title: "YouTube Video",
                authorName: nil,
                thumbnailURL: URL(string: "https://img.youtube.com/vi/\(videoID)/hqdefault.jpg"),
                videoID: videoID
            )
        }

        throw YouTubePreviewError.invalidResponse
    }
}

private struct OEmbedPayload: Decodable {
    var title: String
    var authorName: String?
    var thumbnailURL: String?

    enum CodingKeys: String, CodingKey {
        case title
        case authorName = "author_name"
        case thumbnailURL = "thumbnail_url"
    }
}

enum YouTubeURLParser {
    static func isLikelyYouTubeURL(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else {
            return false
        }

        return host == "youtube.com"
            || host == "www.youtube.com"
            || host == "m.youtube.com"
            || host == "youtu.be"
    }

    static func videoID(from url: URL) -> String? {
        guard let host = url.host?.lowercased() else {
            return nil
        }

        if host == "youtu.be" {
            return url.pathComponents.dropFirst().first
        }

        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let value = components.queryItems?.first(where: { $0.name == "v" })?.value,
           !value.isEmpty {
            return value
        }

        let components = url.pathComponents
        if let shortsIndex = components.firstIndex(of: "shorts"),
           components.indices.contains(shortsIndex + 1) {
            return components[shortsIndex + 1]
        }

        if let embedIndex = components.firstIndex(of: "embed"),
           components.indices.contains(embedIndex + 1) {
            return components[embedIndex + 1]
        }

        return nil
    }
}
