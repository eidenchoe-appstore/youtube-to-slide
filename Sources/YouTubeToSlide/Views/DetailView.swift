import AppKit
import SwiftUI

struct DetailView: View {
    @EnvironmentObject private var store: JobStore
    var job: ExtractionJob

    private let columns = [
        GridItem(.adaptive(minimum: 180, maximum: 260), spacing: 16)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header

                if let detail = job.status.detail {
                    Text(detail)
                        .font(.callout)
                        .foregroundStyle(.red)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                }

                if job.slides.isEmpty {
                    DropZoneView()
                } else {
                    StudyPanelView(job: job)

                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(job.slides) { slide in
                            SlideThumbnailView(
                                slide: slide,
                                isSelected: store.selectedSlideIndex == slide.index || (store.selectedSlideIndex == nil && slide.index == job.slides.first?.index)
                            )
                            .onTapGesture {
                                store.selectSlide(slide.index)
                            }
                        }
                    }
                }
            }
            .padding(24)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(job.title)
                        .font(.title2.weight(.semibold))
                        .lineLimit(2)
                    Text(job.source)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Text(job.status.label)
                    .font(.callout.weight(.medium))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.quaternary, in: Capsule())
            }

            ProgressView(value: job.progress)

            HStack {
                Label("\(job.slides.count) slides", systemImage: "rectangle.stack")
                Text(job.outputDirectory.path)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .foregroundStyle(.secondary)
            }
            .font(.callout)
        }
    }
}

private struct SlideThumbnailView: View {
    var slide: SlideFrame
    var isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                Color.secondary.opacity(0.08)

                if let image = NSImage(contentsOf: slide.fileURL) {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                } else {
                    Image(systemName: "photo")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                }
            }
            .aspectRatio(16 / 9, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(isSelected ? Color.blue : Color.secondary.opacity(0.15), lineWidth: isSelected ? 3 : 1)
            }

            HStack {
                Text("#\(slide.index)")
                    .fontWeight(.medium)
                Spacer()
                Text(AppFormatters.timestamp(slide.timestampSec))
                Text(AppFormatters.percent(slide.changeRatio))
                    .foregroundStyle(.secondary)
            }
            .font(.caption)
        }
    }
}
