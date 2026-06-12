import SwiftUI

struct SidebarView: View {
    @EnvironmentObject private var store: JobStore

    var body: some View {
        VStack(spacing: 0) {
            List(selection: $store.selectedJobID) {
                Section("Batch Queue") {
                    ForEach(store.jobs) { job in
                        JobRowView(job: job)
                            .tag(job.id)
                    }
                }
            }
            .listStyle(.sidebar)

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                ToolStatusRow(name: "ffmpeg", available: store.toolStatus.hasFFmpeg, path: store.toolStatus.ffmpegPath)
                if !store.toolStatus.hasFFmpeg {
                    Button {
                        store.installFFmpeg()
                    } label: {
                        Label(installTitle(for: "ffmpeg"), systemImage: "arrow.down.circle")
                    }
                    .disabled(store.installingFormula != nil)
                }

                ToolStatusRow(name: "yt-dlp", available: store.toolStatus.hasYtDlp, path: store.toolStatus.ytDlpPath)
                if !store.toolStatus.hasYtDlp {
                    Button {
                        store.installYtDlp()
                    } label: {
                        Label(installTitle(for: "yt-dlp"), systemImage: "arrow.down.circle")
                    }
                    .disabled(store.installingFormula != nil)
                }

                Button {
                    store.refreshTools()
                } label: {
                    Label("Refresh Tools", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.link)
            }
            .font(.caption)
            .padding(12)
        }
    }

    private func installTitle(for formula: String) -> String {
        if store.installingFormula == formula {
            return "Installing \(formula)..."
        }
        return "Install \(formula)"
    }
}

private struct JobRowView: View {
    var job: ExtractionJob

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: job.inputType.systemImage)
                .foregroundStyle(.secondary)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 4) {
                Text(job.title)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(job.inputType.label)
                    Text("•")
                    Text(job.status.label)
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                ProgressView(value: job.progress)
                    .progressViewStyle(.linear)
                    .opacity(job.progress > 0 && !job.status.isTerminal ? 1 : 0.35)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct ToolStatusRow: View {
    var name: String
    var available: Bool
    var path: String?

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: available ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(available ? .green : .orange)
            VStack(alignment: .leading, spacing: 1) {
                Text(name)
                    .fontWeight(.medium)
                Text(path ?? "Install with Homebrew")
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }
}
