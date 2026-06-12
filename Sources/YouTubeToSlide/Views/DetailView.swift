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

                processingSection
                slidesSection
                StudyPanelView(job: job)
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

    private var processingSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            WorkspaceSectionHeader(
                title: "Processing",
                subtitle: "Preview the lecture input and run slide extraction."
            )

            HStack(alignment: .top, spacing: 16) {
                VideoPreviewView(job: job)
                    .frame(minWidth: 420, maxWidth: .infinity)

                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Label(job.inputType.label, systemImage: job.inputType.systemImage)
                        Spacer()
                        Text(job.status.label)
                            .font(.callout.weight(.medium))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(.quaternary, in: Capsule())
                    }
                    .font(.callout)

                    ProgressView(value: job.progress)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Output")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(job.outputDirectory.path)
                            .font(.caption)
                            .lineLimit(3)
                            .truncationMode(.middle)
                            .textSelection(.enabled)
                    }

                    HStack(spacing: 10) {
                        if store.isProcessing {
                            Button {
                                store.cancelProcessing()
                            } label: {
                                Label("Cancel", systemImage: "stop.fill")
                            }
                            .controlSize(.large)
                        } else {
                            Button {
                                store.startProcessing()
                            } label: {
                                Label("Start Processing", systemImage: "play.fill")
                                    .font(.headline)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                            .tint(.blue)
                            .disabled(store.jobs.isEmpty || !job.status.canProcess)
                        }

                        Button {
                            store.revealOutput(for: job)
                        } label: {
                            Label("Reveal Output", systemImage: "folder")
                        }
                        .controlSize(.large)
                    }

                    Spacer(minLength: 0)
                }
                .frame(width: 300)
            }
        }
        .padding(16)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.secondary.opacity(0.14))
        }
    }

    private var slidesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            WorkspaceSectionHeader(
                title: "PNG Slides",
                subtitle: "Extracted slide screenshots appear here. Select one to study or chat about it."
            )

            if job.slides.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 36))
                        .foregroundStyle(.secondary)
                    Text("No PNG slides yet")
                        .font(.headline)
                    Text("Click Start Processing to extract slides from the selected lecture.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 180)
                .background(.background, in: RoundedRectangle(cornerRadius: 8))
            } else {
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
        .padding(16)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.secondary.opacity(0.14))
        }
    }
}

private struct WorkspaceSectionHeader: View {
    var title: String
    var subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.headline)
            Text(subtitle)
                .font(.callout)
                .foregroundStyle(.secondary)
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
