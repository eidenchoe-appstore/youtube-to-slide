import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject private var store: JobStore
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 240, ideal: 280, max: 360)
        } detail: {
            HSplitView {
                MainWorkspaceView()
                    .frame(minWidth: 560)

                InspectorView()
                    .frame(minWidth: 300, idealWidth: 340, maxWidth: 420)
            }
        }
        .toolbar {
            ToolbarItemGroup {
                Button {
                    openVideoPanel()
                } label: {
                    Label("Add Video", systemImage: "plus.rectangle.on.folder")
                }

                Button {
                    store.startProcessing()
                } label: {
                    Label("Start Processing", systemImage: "play.fill")
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .disabled(store.isProcessing)

                Button {
                    store.cancelProcessing()
                } label: {
                    Label("Cancel", systemImage: "stop.fill")
                }
                .disabled(!store.isProcessing)

                Button {
                    store.revealOutput(for: store.selectedJob)
                } label: {
                    Label("Reveal Output", systemImage: "folder")
                }
                .disabled(store.selectedJob == nil)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openVideoPanel)) { _ in
            openVideoPanel()
        }
        .alert("YouTube to Slide", isPresented: messageBinding) {
            Button("OK", role: .cancel) {
                store.message = nil
            }
        } message: {
            Text(store.message ?? "")
        }
    }

    private var messageBinding: Binding<Bool> {
        Binding(
            get: { store.message != nil },
            set: { if !$0 { store.message = nil } }
        )
    }

    private func openVideoPanel() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = ["mp4", "mov", "m4v", "avi", "mkv", "webm", "wmv", "flv", "mpg", "mpeg"]
            .compactMap { UTType(filenameExtension: $0) }
        panel.prompt = "Add"

        if panel.runModal() == .OK {
            store.addLocalVideos(panel.urls)
        }
    }
}
