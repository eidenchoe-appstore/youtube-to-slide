import Foundation

struct SlideCandidate {
    var frameURL: URL
    var timestampSec: Double
    var changeRatio: Double
}

struct SlideDetectionService {
    var comparator = ImageComparator()

    func detectSlides(
        from frames: [SampledFrame],
        settings: AppSettings,
        progress: (Double) -> Void
    ) throws -> [SlideCandidate] {
        guard let first = frames.first else {
            return []
        }

        var candidates = [
            SlideCandidate(frameURL: first.url, timestampSec: first.timestampSec, changeRatio: 0)
        ]
        var previous = first

        for index in 1..<frames.count {
            if Task.isCancelled {
                break
            }

            let current = frames[index]
            let ratio = try comparator.changedPixelRatio(
                previous: previous.url,
                current: current.url,
                pixelDelta: settings.pixelDelta,
                compareWidth: settings.compareWidth
            )

            if ratio >= settings.changeThreshold {
                candidates.append(
                    SlideCandidate(
                        frameURL: current.url,
                        timestampSec: current.timestampSec,
                        changeRatio: ratio
                    )
                )
            }

            previous = current
            progress(Double(index + 1) / Double(frames.count))
        }

        return candidates
    }
}
