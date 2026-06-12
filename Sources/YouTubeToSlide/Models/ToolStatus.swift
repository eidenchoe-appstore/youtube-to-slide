import Foundation

struct ToolStatus: Equatable {
    var ffmpegPath: String?
    var ytDlpPath: String?

    var hasFFmpeg: Bool {
        ffmpegPath != nil
    }

    var hasYtDlp: Bool {
        ytDlpPath != nil
    }
}
