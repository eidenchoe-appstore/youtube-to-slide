import Foundation

struct YouTubeDownloadResult {
    var title: String
    var videoURL: URL
}

enum YouTubeDownloadError: LocalizedError {
    case missingYtDlp
    case noDownloadedVideo

    var errorDescription: String? {
        switch self {
        case .missingYtDlp:
            return "yt-dlp is required for YouTube links. Install it with `brew install yt-dlp`."
        case .noDownloadedVideo:
            return "yt-dlp finished but no downloaded video file was found."
        }
    }
}

struct YouTubeDownloadService {
    var ytDlpPath: String?

    func fetchTitle(for url: String) throws -> String {
        guard let ytDlpPath else {
            throw YouTubeDownloadError.missingYtDlp
        }

        let result = try ShellService.run(
            ytDlpPath,
            ["--no-playlist", "--no-warnings", "--print", "title", url]
        )

        let title = result.stdout
            .split(separator: "\n")
            .map(String.init)
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return FileNameSanitizer.sanitize(title ?? "YouTube Video", fallback: "YouTube Video")
    }

    func download(url: String, into temporaryRoot: URL) throws -> YouTubeDownloadResult {
        guard let ytDlpPath else {
            throw YouTubeDownloadError.missingYtDlp
        }

        let title = (try? fetchTitle(for: url)) ?? "YouTube Video"
        let downloadDirectory = temporaryRoot.appendingPathComponent("youtube-download", isDirectory: true)
        try FileManager.default.createDirectory(at: downloadDirectory, withIntermediateDirectories: true)

        try ShellService.run(
            ytDlpPath,
            [
                "--no-playlist",
                "--no-progress",
                "-f", "bv*+ba/b",
                "--merge-output-format", "mp4",
                "-P", downloadDirectory.path,
                "-o", "video.%(ext)s",
                url
            ]
        )

        let files = try FileManager.default.contentsOfDirectory(
            at: downloadDirectory,
            includingPropertiesForKeys: nil
        )

        guard let videoURL = files.first(where: { !$0.hasDirectoryPath }) else {
            throw YouTubeDownloadError.noDownloadedVideo
        }

        return YouTubeDownloadResult(title: title, videoURL: videoURL)
    }
}
