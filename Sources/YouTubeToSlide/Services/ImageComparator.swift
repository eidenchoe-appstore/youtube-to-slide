import AppKit
import Foundation

enum ImageComparatorError: LocalizedError {
    case couldNotLoadImage(URL)
    case couldNotRenderImage(URL)

    var errorDescription: String? {
        switch self {
        case let .couldNotLoadImage(url):
            return "Could not load image: \(url.lastPathComponent)"
        case let .couldNotRenderImage(url):
            return "Could not render image for comparison: \(url.lastPathComponent)"
        }
    }
}

struct ImageComparator {
    func changedPixelRatio(
        previous: URL,
        current: URL,
        pixelDelta: Int,
        compareWidth: Int
    ) throws -> Double {
        let previousPixels = try grayscalePixels(from: previous, maxWidth: compareWidth)
        let currentPixels = try grayscalePixels(from: current, maxWidth: compareWidth)
        let count = min(previousPixels.count, currentPixels.count)

        guard count > 0 else {
            return 1.0
        }

        let threshold = UInt8(clamping: pixelDelta)
        var changed = 0

        for index in 0..<count {
            let lhs = previousPixels[index]
            let rhs = currentPixels[index]
            let diff = lhs > rhs ? lhs - rhs : rhs - lhs
            if diff > threshold {
                changed += 1
            }
        }

        return Double(changed) / Double(count)
    }

    private func grayscalePixels(from url: URL, maxWidth: Int) throws -> [UInt8] {
        guard let image = NSImage(contentsOf: url),
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw ImageComparatorError.couldNotLoadImage(url)
        }

        let sourceWidth = cgImage.width
        let sourceHeight = cgImage.height
        let targetWidth = max(1, min(maxWidth, sourceWidth))
        let targetHeight = max(1, Int(Double(sourceHeight) * Double(targetWidth) / Double(sourceWidth)))
        var pixels = [UInt8](repeating: 0, count: targetWidth * targetHeight)

        let colorSpace = CGColorSpaceCreateDeviceGray()
        guard let context = CGContext(
            data: &pixels,
            width: targetWidth,
            height: targetHeight,
            bitsPerComponent: 8,
            bytesPerRow: targetWidth,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else {
            throw ImageComparatorError.couldNotRenderImage(url)
        }

        context.interpolationQuality = .medium
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight))
        return pixels
    }
}
