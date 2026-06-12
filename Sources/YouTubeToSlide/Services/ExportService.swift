import AppKit
import Foundation
import PDFKit

enum ExportError: LocalizedError {
    case noSlides
    case couldNotCreatePDFPage(URL)
    case couldNotReadImageSize(URL)
    case missingZip

    var errorDescription: String? {
        switch self {
        case .noSlides:
            return "No slides were detected."
        case let .couldNotCreatePDFPage(url):
            return "Could not add \(url.lastPathComponent) to the PDF."
        case let .couldNotReadImageSize(url):
            return "Could not read image dimensions for \(url.lastPathComponent)."
        case .missingZip:
            return "The system zip tool is required to create PPTX files."
        }
    }
}

struct ExportResult {
    var slides: [SlideFrame]
    var timeline: [TimelineEntry]
    var pdfURL: URL?
    var pptxURL: URL?
}

struct ExportService {
    private let baseSlideHeightEMU = 6_858_000

    func export(
        candidates: [SlideCandidate],
        title: String,
        outputDirectory: URL,
        formats: Set<OutputFormat>
    ) throws -> ExportResult {
        guard !candidates.isEmpty else {
            throw ExportError.noSlides
        }

        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

        let safeTitle = FileNameSanitizer.sanitize(title)
        var slides: [SlideFrame] = []

        for (index, candidate) in candidates.enumerated() {
            let slideIndex = index + 1
            let timestamp = AppFormatters.compactTimestampForFilename(candidate.timestampSec)
            let fileName = "\(safeTitle)_\(String(format: "%06d", slideIndex))_\(timestamp).png"
            let destination = outputDirectory.appendingPathComponent(fileName)

            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.copyItem(at: candidate.frameURL, to: destination)

            slides.append(
                SlideFrame(
                    index: slideIndex,
                    timestampSec: candidate.timestampSec,
                    fileURL: destination,
                    changeRatio: candidate.changeRatio
                )
            )
        }

        let timeline = slides.map {
            TimelineEntry(
                slideIndex: $0.index,
                timestampSec: $0.timestampSec,
                fileName: $0.fileURL.lastPathComponent,
                changeRatio: $0.changeRatio
            )
        }

        let timelineURL = outputDirectory.appendingPathComponent("\(safeTitle).timeline.json")
        let timelineData = try JSONEncoder.prettyPrinted.encode(timeline)
        try timelineData.write(to: timelineURL)

        var pdfURL: URL?
        var pptxURL: URL?

        if formats.contains(.pdf) {
            pdfURL = try createPDF(slides: slides, title: safeTitle, outputDirectory: outputDirectory)
        }

        if formats.contains(.pptx) {
            pptxURL = try createPPTX(slides: slides, title: safeTitle, outputDirectory: outputDirectory)
        }

        return ExportResult(slides: slides, timeline: timeline, pdfURL: pdfURL, pptxURL: pptxURL)
    }

    private func createPDF(slides: [SlideFrame], title: String, outputDirectory: URL) throws -> URL {
        let document = PDFDocument()

        for slide in slides {
            guard let image = NSImage(contentsOf: slide.fileURL),
                  let page = PDFPage(image: image) else {
                throw ExportError.couldNotCreatePDFPage(slide.fileURL)
            }
            document.insert(page, at: document.pageCount)
        }

        let outputURL = outputDirectory.appendingPathComponent("\(title).pdf")
        document.write(to: outputURL)
        return outputURL
    }

    private func createPPTX(slides: [SlideFrame], title: String, outputDirectory: URL) throws -> URL {
        guard let zipPath = ToolResolver.resolveExecutable(named: "zip") ?? (FileManager.default.isExecutableFile(atPath: "/usr/bin/zip") ? "/usr/bin/zip" : nil) else {
            throw ExportError.missingZip
        }

        let firstImageSize = try imageSize(for: slides[0].fileURL)
        let canvas = pptxCanvas(for: firstImageSize)
        let buildRoot = outputDirectory.appendingPathComponent(".pptx-build-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: buildRoot) }

        let relsRoot = buildRoot.appendingPathComponent("_rels", isDirectory: true)
        let pptRoot = buildRoot.appendingPathComponent("ppt", isDirectory: true)
        let slideRoot = pptRoot.appendingPathComponent("slides", isDirectory: true)
        let slideRelsRoot = slideRoot.appendingPathComponent("_rels", isDirectory: true)
        let mediaRoot = pptRoot.appendingPathComponent("media", isDirectory: true)
        let presentationRelsRoot = pptRoot.appendingPathComponent("_rels", isDirectory: true)

        for directory in [relsRoot, slideRoot, slideRelsRoot, mediaRoot, presentationRelsRoot] {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }

        for slide in slides {
            let imageName = "image\(slide.index).png"
            try FileManager.default.copyItem(
                at: slide.fileURL,
                to: mediaRoot.appendingPathComponent(imageName)
            )
        }

        try write("[Content_Types].xml", in: buildRoot, contents: contentTypesXML(slideCount: slides.count))
        try write(".rels", in: relsRoot, contents: packageRelsXML())
        try write("presentation.xml", in: pptRoot, contents: presentationXML(slideCount: slides.count, canvas: canvas))
        try write("presentation.xml.rels", in: presentationRelsRoot, contents: presentationRelsXML(slideCount: slides.count))

        for slide in slides {
            let imageSize = try imageSize(for: slide.fileURL)
            let placement = imagePlacement(for: imageSize, in: canvas)
            try write("slide\(slide.index).xml", in: slideRoot, contents: slideXML(imageRelationshipID: "rId1", placement: placement))
            try write("slide\(slide.index).xml.rels", in: slideRelsRoot, contents: slideRelsXML(imageIndex: slide.index))
        }

        let outputURL = outputDirectory.appendingPathComponent("\(title).pptx")
        if FileManager.default.fileExists(atPath: outputURL.path) {
            try FileManager.default.removeItem(at: outputURL)
        }

        try ShellService.run(
            zipPath,
            ["-qr", outputURL.path, "[Content_Types].xml", "_rels", "ppt"],
            currentDirectory: buildRoot
        )

        return outputURL
    }

    private func write(_ fileName: String, in directory: URL, contents: String) throws {
        try contents.data(using: .utf8)?.write(to: directory.appendingPathComponent(fileName))
    }

    private func contentTypesXML(slideCount: Int) -> String {
        let slideOverrides = (1...slideCount).map {
            """
            <Override PartName="/ppt/slides/slide\($0).xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slide+xml"/>
            """
        }.joined()

        return """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
          <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
          <Default Extension="xml" ContentType="application/xml"/>
          <Default Extension="png" ContentType="image/png"/>
          <Override PartName="/ppt/presentation.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml"/>
          \(slideOverrides)
        </Types>
        """
    }

    private func packageRelsXML() -> String {
        """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
          <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="ppt/presentation.xml"/>
        </Relationships>
        """
    }

    private func presentationXML(slideCount: Int, canvas: PPTXCanvas) -> String {
        let slideIDs = (1...slideCount).map {
            """
            <p:sldId id="\(255 + $0)" r:id="rId\($0)"/>
            """
        }.joined()

        return """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <p:presentation xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">
          <p:sldIdLst>
            \(slideIDs)
          </p:sldIdLst>
          <p:sldSz cx="\(canvas.widthEMU)" cy="\(canvas.heightEMU)" type="custom"/>
          <p:notesSz cx="6858000" cy="9144000"/>
        </p:presentation>
        """
    }

    private func presentationRelsXML(slideCount: Int) -> String {
        let relationships = (1...slideCount).map {
            """
            <Relationship Id="rId\($0)" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide" Target="slides/slide\($0).xml"/>
            """
        }.joined()

        return """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
          \(relationships)
        </Relationships>
        """
    }

    private func slideXML(imageRelationshipID: String, placement: PPTXImagePlacement) -> String {
        """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <p:sld xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">
          <p:cSld>
            <p:spTree>
              <p:nvGrpSpPr>
                <p:cNvPr id="1" name=""/>
                <p:cNvGrpSpPr/>
                <p:nvPr/>
              </p:nvGrpSpPr>
              <p:grpSpPr>
                <a:xfrm>
                  <a:off x="0" y="0"/>
                  <a:ext cx="0" cy="0"/>
                  <a:chOff x="0" y="0"/>
                  <a:chExt cx="0" cy="0"/>
                </a:xfrm>
              </p:grpSpPr>
              <p:pic>
                <p:nvPicPr>
                  <p:cNvPr id="2" name="Slide Image"/>
                  <p:cNvPicPr/>
                  <p:nvPr/>
                </p:nvPicPr>
                <p:blipFill>
                  <a:blip r:embed="\(imageRelationshipID)"/>
                  <a:stretch><a:fillRect/></a:stretch>
                </p:blipFill>
                <p:spPr>
                  <a:xfrm>
                    <a:off x="\(placement.xEMU)" y="\(placement.yEMU)"/>
                    <a:ext cx="\(placement.widthEMU)" cy="\(placement.heightEMU)"/>
                  </a:xfrm>
                  <a:prstGeom prst="rect"><a:avLst/></a:prstGeom>
                </p:spPr>
              </p:pic>
            </p:spTree>
          </p:cSld>
          <p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr>
        </p:sld>
        """
    }

    private func slideRelsXML(imageIndex: Int) -> String {
        """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
          <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="../media/image\(imageIndex).png"/>
        </Relationships>
        """
    }

    private func imageSize(for url: URL) throws -> ImagePixelSize {
        guard let image = NSImage(contentsOf: url),
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
              cgImage.width > 0,
              cgImage.height > 0 else {
            throw ExportError.couldNotReadImageSize(url)
        }

        return ImagePixelSize(width: cgImage.width, height: cgImage.height)
    }

    private func pptxCanvas(for imageSize: ImagePixelSize) -> PPTXCanvas {
        let aspectRatio = Double(imageSize.width) / Double(imageSize.height)
        let width = max(1, Int((Double(baseSlideHeightEMU) * aspectRatio).rounded()))
        return PPTXCanvas(widthEMU: width, heightEMU: baseSlideHeightEMU)
    }

    private func imagePlacement(for imageSize: ImagePixelSize, in canvas: PPTXCanvas) -> PPTXImagePlacement {
        let imageAspectRatio = Double(imageSize.width) / Double(imageSize.height)
        let canvasAspectRatio = Double(canvas.widthEMU) / Double(canvas.heightEMU)

        if imageAspectRatio >= canvasAspectRatio {
            let width = canvas.widthEMU
            let height = max(1, Int((Double(width) / imageAspectRatio).rounded()))
            return PPTXImagePlacement(
                xEMU: 0,
                yEMU: max(0, (canvas.heightEMU - height) / 2),
                widthEMU: width,
                heightEMU: height
            )
        } else {
            let height = canvas.heightEMU
            let width = max(1, Int((Double(height) * imageAspectRatio).rounded()))
            return PPTXImagePlacement(
                xEMU: max(0, (canvas.widthEMU - width) / 2),
                yEMU: 0,
                widthEMU: width,
                heightEMU: height
            )
        }
    }
}

private struct ImagePixelSize {
    var width: Int
    var height: Int
}

private struct PPTXCanvas {
    var widthEMU: Int
    var heightEMU: Int
}

private struct PPTXImagePlacement {
    var xEMU: Int
    var yEMU: Int
    var widthEMU: Int
    var heightEMU: Int
}

private extension JSONEncoder {
    static var prettyPrinted: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}
