import Foundation

struct ShellResult {
    var stdout: String
    var stderr: String
    var exitCode: Int32
}

enum ShellError: LocalizedError {
    case launchFailed(String)
    case nonZeroExit(command: String, exitCode: Int32, stderr: String)

    var errorDescription: String? {
        switch self {
        case let .launchFailed(message):
            return message
        case let .nonZeroExit(command, exitCode, stderr):
            let detail = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            if detail.isEmpty {
                return "\(command) failed with exit code \(exitCode)."
            }
            return "\(command) failed with exit code \(exitCode): \(detail)"
        }
    }
}

enum ShellService {
    @discardableResult
    static func run(
        _ executable: String,
        _ arguments: [String],
        currentDirectory: URL? = nil,
        allowNonZeroExit: Bool = false
    ) throws -> ShellResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        if let currentDirectory {
            process.currentDirectoryURL = currentDirectory
        }

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        do {
            try process.run()
        } catch {
            throw ShellError.launchFailed("Could not launch \(executable): \(error.localizedDescription)")
        }

        process.waitUntilExit()

        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
        let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
        let stderr = String(data: stderrData, encoding: .utf8) ?? ""
        let result = ShellResult(stdout: stdout, stderr: stderr, exitCode: process.terminationStatus)

        if !allowNonZeroExit && result.exitCode != 0 {
            throw ShellError.nonZeroExit(
                command: ([executable] + arguments).joined(separator: " "),
                exitCode: result.exitCode,
                stderr: stderr
            )
        }

        return result
    }
}
