import Foundation

struct YouTubePreview: Equatable {
    var sourceURL: String
    var title: String
    var authorName: String?
    var thumbnailURL: URL?
    var videoID: String?
}
