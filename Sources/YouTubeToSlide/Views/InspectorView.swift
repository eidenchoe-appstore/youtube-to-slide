import SwiftUI

struct InspectorView: View {
    @EnvironmentObject private var store: JobStore

    var body: some View {
        TabView {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    processingSection
                    outputSection
                    selectedJobSection
                    accelerationSection
                }
                .padding(18)
            }
            .tabItem {
                Label("Processing", systemImage: "slider.horizontal.3")
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    openRouterAPISection
                    notionAPISection
                    modelFallbackSection
                }
                .padding(18)
            }
            .tabItem {
                Label("API Settings", systemImage: "key.fill")
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    devLogSummarySection
                    devLogSection
                }
                .padding(18)
            }
            .tabItem {
                Label("Log (Dev)", systemImage: "terminal")
            }
        }
        .background(.regularMaterial)
    }

    private var processingSection: some View {
        InspectorSection("Processing") {
            VStack(alignment: .leading, spacing: 12) {
                Stepper(value: $store.settings.sampleInterval, in: 0.5...10, step: 0.5) {
                    SettingValueRow(label: "Sampling", value: String(format: "%.1f sec", store.settings.sampleInterval))
                }

                VStack(alignment: .leading, spacing: 6) {
                    SettingValueRow(label: "Change threshold", value: AppFormatters.percent(store.settings.changeThreshold))
                    Slider(value: $store.settings.changeThreshold, in: 0.01...0.80, step: 0.005)
                }

                Stepper(value: $store.settings.pixelDelta, in: 1...100, step: 1) {
                    SettingValueRow(label: "Pixel delta", value: "\(store.settings.pixelDelta)")
                }

                Stepper(value: $store.settings.compareWidth, in: 160...1280, step: 80) {
                    SettingValueRow(label: "Compare width", value: "\(store.settings.compareWidth) px")
                }
            }
        }
    }

    private var outputSection: some View {
        InspectorSection("Output") {
            VStack(alignment: .leading, spacing: 12) {
                Toggle("PNG folder", isOn: $store.settings.exportPNG)
                Toggle("PDF", isOn: $store.settings.exportPDF)
                Toggle("PPTX", isOn: $store.settings.exportPPTX)

                Picker("Resolution", selection: $store.settings.resolution) {
                    ForEach(ResolutionPreset.allCases) { preset in
                        Text(preset.label).tag(preset)
                    }
                }

                if store.settings.resolution == .customWidth {
                    Stepper(value: $store.settings.customWidth, in: 320...3840, step: 80) {
                        SettingValueRow(label: "Custom width", value: "\(store.settings.customWidth) px")
                    }
                }

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Default YouTube output")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(store.settings.defaultOutputDirectory?.path ?? OutputPathResolver.defaultDownloadsRoot().path)
                        .font(.caption)
                        .lineLimit(2)
                        .truncationMode(.middle)

                    HStack {
                        Button("Choose Folder") {
                            chooseDefaultOutputDirectory()
                        }
                        Button("Reset") {
                            store.setDefaultOutputDirectory(nil)
                        }
                    }
                }
            }
        }
    }

    private var openRouterAPISection: some View {
        InspectorSection("OpenRouter API") {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: store.hasOpenRouterAPIKey ? "checkmark.circle.fill" : "key.fill")
                        .foregroundStyle(store.hasOpenRouterAPIKey ? .green : .secondary)
                    Text(store.hasOpenRouterAPIKey ? "OpenRouter API key saved" : "OpenRouter API key required")
                        .font(.callout)
                }

                SecureField("OpenRouter API key", text: $store.openRouterAPIKeyInput)
                    .textFieldStyle(.roundedBorder)

                HStack {
                    Button("Save Key") {
                        store.saveOpenRouterAPIKey()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(store.openRouterAPIKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    Button("Clear") {
                        store.clearOpenRouterAPIKey()
                    }
                    .disabled(!store.hasOpenRouterAPIKey)
                }
            }
        }
    }

    private var notionAPISection: some View {
        InspectorSection("Notion API") {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: store.hasNotionAPIKey ? "checkmark.circle.fill" : "key.fill")
                        .foregroundStyle(store.hasNotionAPIKey ? .green : .secondary)
                    Text(store.hasNotionAPIKey ? "Notion API token saved" : "Notion API token required")
                        .font(.callout)
                }

                if let connectionName = store.notionConnectionName {
                    Label("Using integration: \(connectionName)", systemImage: "person.crop.circle.badge.checkmark")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                    Text("If this is not the integration you expect, clear the token and save the correct Notion integration token.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                SecureField("Notion API token", text: $store.notionAPIKeyInput)
                    .textFieldStyle(.roundedBorder)

                HStack {
                    Button("Save Token") {
                        store.saveNotionAPIKey()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(store.notionAPIKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || store.isValidatingNotionAPIKey)

                    Button("Clear") {
                        store.clearNotionAPIKey()
                    }
                    .disabled(!store.hasNotionAPIKey || store.isValidatingNotionAPIKey)
                }

                if store.isValidatingNotionAPIKey {
                    ProgressView("Checking Notion token...")
                        .font(.caption)
                }

                Divider()

                TextField("Parent page URL or page ID", text: notionParentPageURLBinding, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(2...3)

                Text("Share the parent page with your Notion integration before sending. The app creates a new child page under this parent.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var modelFallbackSection: some View {
        InspectorSection("Model Fallback") {
            VStack(alignment: .leading, spacing: 12) {
                Picker("First model", selection: primaryModelBinding) {
                    ForEach(OpenRouterStudyModel.allCases) { model in
                        Text(model.displayName)
                            .tag(model.id)
                    }
                }

                modelDescription(for: store.settings.primaryStudyModelID)

                Divider()

                Picker("Second model", selection: fallbackModelBinding) {
                    ForEach(OpenRouterStudyModel.allCases) { model in
                        Text(model.displayName)
                            .tag(model.id)
                    }
                }

                modelDescription(for: store.settings.fallbackStudyModelID)

                if store.settings.primaryStudyModelID == store.settings.fallbackStudyModelID {
                    Label("First and second models are the same, so fallback will be skipped.", systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Label("If the first model is rate-limited or temporarily unavailable, the app retries with the second model.", systemImage: "arrow.triangle.2.circlepath")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var devLogSummarySection: some View {
        InspectorSection("Runtime Snapshot") {
            VStack(alignment: .leading, spacing: 8) {
                SettingValueRow(label: "Jobs", value: "\(store.jobs.count)")
                SettingValueRow(label: "Processing", value: store.isProcessing ? "Running" : "Idle")
                SettingValueRow(label: "Study notes", value: store.isGeneratingStudyNotes ? "Running" : "Idle")
                SettingValueRow(label: "Notion upload", value: store.isCreatingNotionPage ? "Running" : "Idle")
                SettingValueRow(label: "ffmpeg", value: store.toolStatus.hasFFmpeg ? "Available" : "Missing")
                SettingValueRow(label: "yt-dlp", value: store.toolStatus.hasYtDlp ? "Available" : "Missing")

                if let job = store.selectedJob {
                    Divider()
                    Text(job.title)
                        .font(.caption.weight(.semibold))
                        .lineLimit(2)
                        .textSelection(.enabled)
                    SettingValueRow(label: "Selected status", value: job.status.label)
                    SettingValueRow(label: "Slides", value: "\(job.slides.count)")
                    if let detail = job.status.detail {
                        Text(detail)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .textSelection(.enabled)
                    }
                }
            }
        }
    }

    private var devLogSection: some View {
        InspectorSection("Session Log") {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Button("Copy") {
                        store.copyDevLogsToClipboard()
                    }
                    .disabled(store.devLogEntries.isEmpty)

                    Button("Clear") {
                        store.clearDevLogs()
                    }
                    .disabled(store.devLogEntries.isEmpty)

                    Spacer()

                    Text("\(store.devLogEntries.count) entries")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text("Local session log. API key values are not recorded.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if store.devLogEntries.isEmpty {
                    Text("No log entries yet.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(store.devLogEntries.reversed())) { entry in
                            DevLogEntryRow(entry: entry)
                            Divider()
                        }
                    }
                }
            }
        }
    }

    private var primaryModelBinding: Binding<String> {
        Binding {
            store.settings.primaryStudyModelID
        } set: { modelID in
            store.setPrimaryStudyModelID(modelID)
        }
    }

    private var fallbackModelBinding: Binding<String> {
        Binding {
            store.settings.fallbackStudyModelID
        } set: { modelID in
            store.setFallbackStudyModelID(modelID)
        }
    }

    private var notionParentPageURLBinding: Binding<String> {
        Binding {
            store.settings.notionParentPageURL
        } set: { parentPageURL in
            store.setNotionParentPageURL(parentPageURL)
        }
    }

    private func modelDescription(for modelID: String) -> some View {
        let model = OpenRouterStudyModel.model(for: modelID)
        return VStack(alignment: .leading, spacing: 4) {
            Text(model.id)
                .font(.caption)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
            Text(model.badge)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(model.advantage)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var selectedJobSection: some View {
        InspectorSection("Selected Job") {
            if let job = store.selectedJob {
                VStack(alignment: .leading, spacing: 10) {
                    Text(job.outputDirectory.path)
                        .font(.caption)
                        .lineLimit(3)
                        .truncationMode(.middle)

                    HStack {
                        Button("Choose Folder") {
                            chooseOutputDirectory(for: job)
                        }
                        .disabled(job.status != .queued)

                        Button("Reveal Output") {
                            store.revealOutput(for: job)
                        }
                    }
                }
            } else {
                Text("Add a video or YouTube URL to configure its output folder.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var accelerationSection: some View {
        InspectorSection("Acceleration") {
            VStack(alignment: .leading, spacing: 8) {
                Label("Auto", systemImage: "bolt.fill")
                    .font(.headline)
                Text("ffmpeg handles video decoding. Frame comparison runs locally with a lightweight CPU path; the engine is isolated for future Metal acceleration.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func chooseDefaultOutputDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose"

        if panel.runModal() == .OK {
            store.setDefaultOutputDirectory(panel.url)
        }
    }

    private func chooseOutputDirectory(for job: ExtractionJob) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose"

        if panel.runModal() == .OK, let url = panel.url {
            store.setOutputDirectory(url, for: job.id)
        }
    }
}

private struct InspectorSection<Content: View>: View {
    var title: String
    @ViewBuilder var content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
            content
        }
    }
}

private struct SettingValueRow: View {
    var label: String
    var value: String

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
    }
}

private struct DevLogEntryRow: View {
    var entry: DevLogEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(entry.level.rawValue)
                    .font(.caption2.weight(.semibold).monospaced())
                    .foregroundStyle(levelColor)
                Text(entry.timestamp)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            Text(entry.message)
                .font(.caption.monospaced())
                .foregroundStyle(.primary)
                .textSelection(.enabled)
        }
        .padding(.vertical, 6)
    }

    private var levelColor: Color {
        switch entry.level {
        case .debug:
            return .secondary
        case .info:
            return .blue
        case .success:
            return .green
        case .warning:
            return .orange
        case .error:
            return .red
        }
    }
}
