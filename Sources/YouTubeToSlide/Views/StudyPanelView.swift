import SwiftUI

struct StudyPanelView: View {
    @EnvironmentObject private var store: JobStore
    var job: ExtractionJob
    var showsHeader = true
    var usesContainer = true

    @State private var chatScope: StudyChatScope = .selectedSlide
    @State private var chatInput = ""

    var body: some View {
        if usesContainer {
            content
                .padding(16)
                .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.secondary.opacity(0.14))
                }
        } else {
            content
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 14) {
            if showsHeader {
                header
            }

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
                    store.createNoteToNotionPageForSelectedJob()
                } label: {
                    Label(store.isCreatingNotionPage ? "Creating Notion Page" : "Note to Notion Page", systemImage: "doc.richtext")
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .disabled(job.slides.isEmpty)
                .disabled(store.isGeneratingStudyNotes)
                .disabled(!canSendToNotion)
                .help("Generate missing study notes, upload slide images, and create a child page in Notion.")

                Spacer()
            }

            if !canSendToNotion {
                Label(notionRequirementMessage, systemImage: "lock.fill")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
            }

            if store.isGeneratingStudyNotes {
                ProgressView(value: store.studyProgress)
                Text(store.isCreatingNotionPage ? "Generating missing notes before sending to Notion..." : "Generating study notes...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if store.isCreatingNotionPage {
                ProgressView()
                Text("Uploading slide images and creating the Notion page...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if job.notionPageURL != nil {
                HStack {
                    Label("Notion page created", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Spacer()
                    Button {
                        store.openNotionPage(for: job)
                    } label: {
                        Label("Open in Notion", systemImage: "arrow.up.right.square")
                    }
                }
                .font(.callout)
            }

            notePreview

            Divider()

            chatView
        }
    }

    private var allSlidesHaveNotes: Bool {
        guard !job.slides.isEmpty else {
            return false
        }

        return job.slides.allSatisfy { slide in
            let note = job.studyNotes[slide.index]?.markdown.trimmingCharacters(in: .whitespacesAndNewlines)
            return !(note?.isEmpty ?? true)
        }
    }

    private var canSendToNotion: Bool {
        let hasParentPage = !store.settings.notionParentPageURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasStudyContext = store.hasOpenRouterAPIKey || allSlidesHaveNotes
        return store.hasNotionAPIKey && hasParentPage && hasStudyContext
    }

    private var notionRequirementMessage: String {
        if !store.hasNotionAPIKey {
            return "Save a Notion API token in API Settings before sending pages to Notion."
        }

        if store.settings.notionParentPageURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Enter a Notion parent page URL in API Settings before sending pages to Notion."
        }

        if !store.hasOpenRouterAPIKey && !allSlidesHaveNotes {
            return "Save an OpenRouter API key or generate all slide notes before sending the full study page."
        }

        return "Complete Notion and OpenRouter settings before sending the page."
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
                Text("Select a slide and click Study Selected, or click Note to Notion Page to generate missing notes and create a Notion child page.")
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
