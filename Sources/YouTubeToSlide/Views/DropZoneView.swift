import SwiftUI
import UniformTypeIdentifiers

struct DropZoneView: View {
    @EnvironmentObject private var store: JobStore
    var compact = false
    @State private var isTargeted = false

    var body: some View {
        VStack(spacing: compact ? 8 : 16) {
            Image(systemName: "square.and.arrow.down.on.square")
                .font(.system(size: compact ? 22 : 42, weight: .regular))
                .foregroundStyle(isTargeted ? .blue : .secondary)

            VStack(spacing: 4) {
                Text("Drop lecture videos here")
                    .font(compact ? .headline : .title3.weight(.semibold))
                Text("MP4, MOV, M4V, AVI, MKV, WebM and other ffmpeg-readable files")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            if !compact {
                Button {
                    NotificationCenter.default.post(name: .openVideoPanel, object: nil)
                } label: {
                    Label("Choose Video Files", systemImage: "folder.badge.plus")
                }
                .controlSize(.large)
            }
        }
        .frame(maxWidth: .infinity, minHeight: compact ? 112 : 320)
        .padding(compact ? 16 : 28)
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(isTargeted ? Color.blue.opacity(0.10) : Color.secondary.opacity(0.08))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [7, 6]))
                .foregroundStyle(isTargeted ? Color.blue : Color.secondary.opacity(0.45))
        }
        .onDrop(of: [UTType.fileURL.identifier], isTargeted: $isTargeted) { providers in
            handleDrop(providers)
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        var didAccept = false

        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                didAccept = true
                provider.loadDataRepresentation(forTypeIdentifier: UTType.fileURL.identifier) { data, _ in
                    guard let data,
                          let url = URL(dataRepresentation: data, relativeTo: nil) else {
                        return
                    }

                    Task { @MainActor in
                        store.addLocalVideos([url])
                    }
                }
            }
        }

        return didAccept
    }
}
