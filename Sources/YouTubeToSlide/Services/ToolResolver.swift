import Foundation

enum ToolResolver {
    static func resolve() -> ToolStatus {
        ToolStatus(
            ffmpegPath: resolveExecutable(named: "ffmpeg"),
            ytDlpPath: resolveExecutable(named: "yt-dlp")
        )
    }

    static func resolveExecutable(named name: String) -> String? {
        let fixedPaths = [
            "/opt/homebrew/bin/\(name)",
            "/usr/local/bin/\(name)"
        ]

        for path in fixedPaths where FileManager.default.isExecutableFile(atPath: path) {
            return path
        }

        if let result = try? ShellService.run("/usr/bin/which", [name], allowNonZeroExit: true),
           result.exitCode == 0 {
            let candidate = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            if !candidate.isEmpty {
                return candidate
            }
        }

        return nil
    }
}
