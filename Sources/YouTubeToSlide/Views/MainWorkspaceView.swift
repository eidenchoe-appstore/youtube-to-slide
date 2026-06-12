import SwiftUI

struct MainWorkspaceView: View {
    @EnvironmentObject private var store: JobStore
    @State private var youtubeURL = ""

    var body: some View {
        VStack(spacing: 0) {
            InputHeaderView(youtubeURL: $youtubeURL)
                .padding(20)

            Divider()

            if let job = store.selectedJob {
                DetailView(job: job)
            } else {
                EmptyWorkspaceView()
            }
        }
        .background(.background)
    }
}

private struct InputHeaderView: View {
    @EnvironmentObject private var store: JobStore
    @Binding var youtubeURL: String
    @State private var previewState: PreviewLoadState = .idle

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                TextField("Paste a YouTube lecture URL", text: $youtubeURL)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(addURL)

                Button {
                    addURL()
                } label: {
                    Label("Add", systemImage: "plus")
                }
                .keyboardShortcut(.return, modifiers: [])
            }

            YouTubePreviewCard(state: previewState)

            HStack {
                Spacer()

                if store.isProcessing {
                    Button {
                        store.cancelProcessing()
                    } label: {
                        Label("Cancel", systemImage: "stop.fill")
                    }
                    .controlSize(.large)
                }

                Button {
                    store.startProcessing()
                } label: {
                    Label("Start Processing", systemImage: "play.fill")
                        .font(.headline)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(.blue)
                .disabled(store.isProcessing || store.jobs.isEmpty)
            }
        }
        .task(id: youtubeURL) {
            await loadPreview(for: youtubeURL)
        }
        .onReceive(NotificationCenter.default.publisher(for: .loadDemoYouTubeURL)) { notification in
            guard let demoURL = notification.object as? String else {
                return
            }
            youtubeURL = demoURL
        }
    }

    private func addURL() {
        if case let .loaded(preview) = previewState {
            store.addYouTubeURL(youtubeURL, preview: preview)
        } else {
            store.addYouTubeURL(youtubeURL)
        }
        youtubeURL = ""
        previewState = .idle
    }

    private func loadPreview(for rawURL: String) async {
        let trimmed = rawURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            previewState = .idle
            return
        }

        guard let url = URL(string: trimmed),
              YouTubeURLParser.isLikelyYouTubeURL(url) else {
            previewState = trimmed.lowercased().hasPrefix("http") ? .failed("Enter a valid YouTube URL.") : .idle
            return
        }

        previewState = .loading

        do {
            try await Task.sleep(nanoseconds: 450_000_000)
            let preview = try await YouTubePreviewService().preview(for: trimmed)
            previewState = .loaded(preview)
        } catch is CancellationError {
        } catch {
            previewState = .failed(error.localizedDescription)
        }
    }
}

private struct EmptyWorkspaceView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "rectangle.stack.badge.plus")
                .font(.system(size: 42, weight: .regular))
                .foregroundStyle(.secondary)

            Text("Add a lecture to begin")
                .font(.title3.weight(.semibold))

            Text("Drop a video in the left sidebar or paste a YouTube URL above.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(28)
    }
}

private enum PreviewLoadState: Equatable {
    case idle
    case loading
    case loaded(YouTubePreview)
    case failed(String)
}

private struct YouTubePreviewCard: View {
    var state: PreviewLoadState

    var body: some View {
        switch state {
        case .idle:
            EmptyView()
        case .loading:
            HStack(spacing: 10) {
                ProgressView()
                    .controlSize(.small)
                Text("Loading YouTube preview...")
                    .foregroundStyle(.secondary)
            }
            .font(.callout)
            .frame(maxWidth: .infinity, alignment: .leading)
        case let .failed(message):
            Label(message, systemImage: "exclamationmark.triangle")
                .font(.callout)
                .foregroundStyle(.orange)
                .frame(maxWidth: .infinity, alignment: .leading)
        case let .loaded(preview):
            HStack(spacing: 12) {
                ZStack {
                    Color.secondary.opacity(0.12)
                    if let thumbnailURL = preview.thumbnailURL {
                        AsyncImage(url: thumbnailURL) { phase in
                            switch phase {
                            case let .success(image):
                                image
                                    .resizable()
                                    .scaledToFill()
                            case .failure:
                                Image(systemName: "play.rectangle")
                                    .font(.title2)
                                    .foregroundStyle(.secondary)
                            case .empty:
                                ProgressView()
                                    .controlSize(.small)
                            @unknown default:
                                EmptyView()
                            }
                        }
                    } else {
                        Image(systemName: "play.rectangle")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 120, height: 68)
                .clipShape(RoundedRectangle(cornerRadius: 6))

                VStack(alignment: .leading, spacing: 4) {
                    Text(preview.title)
                        .font(.headline)
                        .lineLimit(2)
                    if let authorName = preview.authorName {
                        Text(authorName)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Text("Preview ready")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(10)
            .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        }
    }
}
