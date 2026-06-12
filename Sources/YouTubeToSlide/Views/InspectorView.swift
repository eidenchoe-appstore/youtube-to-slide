import SwiftUI

struct InspectorView: View {
    @EnvironmentObject private var store: JobStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                processingSection
                outputSection
                studySection
                selectedJobSection
                accelerationSection
            }
            .padding(18)
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

    private var studySection: some View {
        InspectorSection("AI Study Notes") {
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

                Picker("Model", selection: $store.settings.studyModelID) {
                    ForEach(OpenRouterStudyModel.allCases) { model in
                        Text("\(model.displayName) - \(model.badge)")
                            .tag(model.id)
                    }
                }

                let model = OpenRouterStudyModel.model(for: store.settings.studyModelID)
                Text(model.id)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                Text(model.advantage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
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
