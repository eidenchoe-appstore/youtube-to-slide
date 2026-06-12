import AppKit
import SwiftUI

struct DetailView: View {
    @EnvironmentObject private var store: JobStore
    var job: ExtractionJob
    @State private var isProcessingExpanded = true
    @State private var isSlidesExpanded = true
    @State private var isStudyExpanded = true

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

                CollapsibleWorkspaceSection(
                    title: "Processing",
                    subtitle: "Preview the lecture input and run slide extraction.",
                    systemImage: "play.rectangle",
                    badge: job.status.label,
                    isExpanded: $isProcessingExpanded
                ) {
                    processingSection
                }

                CollapsibleWorkspaceSection(
                    title: "PNG Slides",
                    subtitle: "Review extracted screenshots and choose a slide for study/chat.",
                    systemImage: "rectangle.stack",
                    badge: "\(job.slides.count) slides",
                    isExpanded: $isSlidesExpanded
                ) {
                    slidesSection
                }

                CollapsibleWorkspaceSection(
                    title: "Chat & Study",
                    subtitle: "Generate full-deck study notes and export a Notion page ZIP.",
                    systemImage: "doc.richtext",
                    badge: "\(job.studyNotes.count)/\(job.slides.count) noted",
                    isExpanded: $isStudyExpanded
                ) {
                    StudyPanelView(job: job, showsHeader: false, usesContainer: false)
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

    private var processingSection: some View {
        VStack(alignment: .leading, spacing: 14) {
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
    }

    private var slidesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
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
    }
}

private struct CollapsibleWorkspaceSection<Content: View>: View {
    var title: String
    var subtitle: String
    var systemImage: String
    var badge: String
    @Binding var isExpanded: Bool
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.18)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 16)

                    Image(systemName: systemImage)
                        .foregroundStyle(.blue)
                        .frame(width: 22)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(title)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text(subtitle)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }

                    Spacer()

                    Text(badge)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.quaternary, in: Capsule())
                }
                .contentShape(Rectangle())
                .padding(14)
            }
            .buttonStyle(.plain)

            if isExpanded {
                Divider()
                content
                    .padding(16)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.secondary.opacity(0.14))
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
