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
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                    guard let url = fileURL(from: item) else {
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

    private func fileURL(from item: NSSecureCoding?) -> URL? {
        if let url = item as? URL {
            return url.isFileURL ? url : nil
        }

        if let url = item as? NSURL {
            let bridgedURL = url as URL
            return bridgedURL.isFileURL ? bridgedURL : nil
        }

        if let data = item as? Data {
            if let url = URL(dataRepresentation: data, relativeTo: nil),
               url.isFileURL {
                return url
            }

            if let string = String(data: data, encoding: .utf8),
               let url = URL(string: string.trimmingCharacters(in: .whitespacesAndNewlines)),
               url.isFileURL {
                return url
            }
        }

        if let string = item as? String {
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            if let url = URL(string: trimmed), url.isFileURL {
                return url
            }
            let fileURL = URL(fileURLWithPath: trimmed)
            return fileURL.path.isEmpty ? nil : fileURL
        }

        return nil
    }
}
