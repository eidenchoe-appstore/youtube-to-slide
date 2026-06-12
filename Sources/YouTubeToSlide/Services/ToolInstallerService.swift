import Foundation

enum ToolInstallerError: LocalizedError {
    case missingHomebrew

    var errorDescription: String? {
        switch self {
        case .missingHomebrew:
            return "Homebrew was not found. Install Homebrew first, then run `brew install ffmpeg yt-dlp`."
        }
    }
}

struct ToolInstallerService {
    static func resolveBrewPath() -> String? {
        let fixedPaths = [
            "/opt/homebrew/bin/brew",
            "/usr/local/bin/brew"
        ]

        for path in fixedPaths where FileManager.default.isExecutableFile(atPath: path) {
            return path
        }

        if let result = try? ShellService.run("/usr/bin/which", ["brew"], allowNonZeroExit: true),
           result.exitCode == 0 {
            let candidate = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            if !candidate.isEmpty {
                return candidate
            }
        }

        return nil
    }

    func install(formula: String) throws {
        guard let brewPath = Self.resolveBrewPath() else {
            throw ToolInstallerError.missingHomebrew
        }

        try ShellService.run(brewPath, ["install", formula])
    }
}
