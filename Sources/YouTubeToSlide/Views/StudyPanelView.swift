import SwiftUI

struct StudyPanelView: View {
    @EnvironmentObject private var store: JobStore
    var job: ExtractionJob

    @State private var chatScope: StudyChatScope = .selectedSlide
    @State private var chatInput = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            HStack(spacing: 10) {
                Button {
                    store.generateSelectedSlideStudyNote()
                } label: {
                    Label("Study Selected", systemImage: "sparkles")
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .disabled(!store.hasOpenRouterAPIKey || store.isGeneratingStudyNotes || store.selectedSlide == nil)

                Button {
                    store.generateAllSlideStudyNotes()
                } label: {
                    Label("Study All Slides", systemImage: "rectangle.stack.badge.play")
                }
                .disabled(!store.hasOpenRouterAPIKey || store.isGeneratingStudyNotes || job.slides.isEmpty)

                Button {
                    store.exportNoteToNotionPageForSelectedJob()
                } label: {
                    Label("Note to Notion Page", systemImage: "square.and.arrow.down.on.square")
                }
                .disabled(job.slides.isEmpty)

                Spacer()
            }

            if !store.hasOpenRouterAPIKey {
                Label("Save an OpenRouter API key in the inspector to enable study notes and chat.", systemImage: "lock.fill")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
            }

            if store.isGeneratingStudyNotes {
                ProgressView(value: store.studyProgress)
            }

            notePreview

            Divider()

            chatView
        }
        .padding(16)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.secondary.opacity(0.14))
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("Chat & Study")
                    .font(.headline)
                Text("Use OpenRouter vision models to explain selected slides or the full deck.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("\(job.studyNotes.count)/\(job.slides.count) noted")
                .font(.caption.weight(.medium))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.quaternary, in: Capsule())
        }
    }

    @ViewBuilder
    private var notePreview: some View {
        let selectedIndex = store.selectedSlide?.index ?? job.slides.first?.index

        VStack(alignment: .leading, spacing: 8) {
            Text("Selected Slide Note")
                .font(.subheadline.weight(.semibold))

            if let selectedIndex,
               let note = job.studyNotes[selectedIndex] {
                ScrollView {
                    Text(note.markdown)
                        .font(.callout)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(minHeight: 120, maxHeight: 220)
                .padding(10)
                .background(.background, in: RoundedRectangle(cornerRadius: 8))
            } else {
                Text("Select a slide and click Study Selected, or generate notes for all slides.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(.background, in: RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    private var chatView: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Chat")
                    .font(.subheadline.weight(.semibold))

                Spacer()

                Picker("Scope", selection: $chatScope) {
                    ForEach(StudyChatScope.allCases) { scope in
                        Text(scope.label).tag(scope)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 260)
                .disabled(!store.hasOpenRouterAPIKey)
            }

            if !store.hasOpenRouterAPIKey {
                Text("Chat is disabled until an OpenRouter API key is saved.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(.background, in: RoundedRectangle(cornerRadius: 8))
            } else if job.chatMessages.isEmpty {
                Text("Ask about the selected slide or the whole lecture.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(job.chatMessages) { message in
                            ChatBubble(message: message)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 220)
            }

            HStack(spacing: 10) {
                TextField("Ask a study question", text: $chatInput, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...3)
                    .onSubmit(sendChat)
                    .disabled(!store.hasOpenRouterAPIKey)

                Button {
                    sendChat()
                } label: {
                    Label("Ask", systemImage: "paperplane.fill")
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .disabled(!store.hasOpenRouterAPIKey || chatInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private func sendChat() {
        let question = chatInput
        chatInput = ""
        store.askStudyQuestion(question, scope: chatScope)
    }
}

private struct ChatBubble: View {
    var message: StudyChatMessage

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(message.role.label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(message.role == .user ? .blue : .secondary)
            Text(message.content)
                .font(.callout)
                .textSelection(.enabled)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(message.role == .user ? Color.blue.opacity(0.08) : Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }
}
