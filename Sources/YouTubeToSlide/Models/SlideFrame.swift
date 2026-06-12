import Foundation

struct SlideFrame: Identifiable, Codable, Equatable {
    let id: UUID
    var index: Int
    var timestampSec: Double
    var fileURL: URL
    var changeRatio: Double

    init(index: Int, timestampSec: Double, fileURL: URL, changeRatio: Double) {
        self.id = UUID()
        self.index = index
        self.timestampSec = timestampSec
        self.fileURL = fileURL
        self.changeRatio = changeRatio
    }
}

struct TimelineEntry: Codable, Equatable {
    var slideIndex: Int
    var timestampSec: Double
    var fileName: String
    var changeRatio: Double
}
