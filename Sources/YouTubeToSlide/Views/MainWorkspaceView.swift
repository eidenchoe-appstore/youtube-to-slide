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
                DropZoneView()
                    .padding(28)
            }
        }
        .background(.background)
    }
}

private struct InputHeaderView: View {
    @EnvironmentObject private var store: JobStore
    @Binding var youtubeURL: String

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

            DropZoneView(compact: true)
        }
    }

    private func addURL() {
        store.addYouTubeURL(youtubeURL)
        youtubeURL = ""
    }
}
