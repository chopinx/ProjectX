import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct SettingsView: View {
    @Bindable var settings: AppSettings
    @Environment(\.modelContext) private var context

    @State private var apiKeyInput = ""
    @State private var isValidating = false
    @State private var validationResult: ValidationResult?
    @State private var showingRestoreTagsAlert = false

    // Export/Import state
    @State private var showingExportSheet = false
    @State private var showingImportPicker = false
    @State private var showingImportSheet = false
    @State private var importData: Data?
    @State private var importPreview: ImportPreview?
    @State private var importResult: ImportResult?
    @State private var exportError: String?
    @State private var importError: String?

    enum ValidationResult {
        case success
        case error(String)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Provider", selection: $settings.selectedProvider) {
                        ForEach(LLMProvider.allCases) { provider in
                            Text(provider.rawValue).tag(provider)
                        }
                    }
                    .onChange(of: settings.selectedProvider) {
                        apiKeyInput = settings.currentAPIKey
                        validationResult = nil
                    }
                } header: {
                    Text("LLM Provider")
                } footer: {
                    Text("Select the AI service to use for receipt scanning")
                }

                Section {
                    switch settings.selectedProvider {
                    case .openai:
                        Picker("Model", selection: $settings.selectedOpenAIModel) {
                            ForEach(OpenAIModel.allCases) { model in
                                Text(model.displayName).tag(model)
                            }
                        }
                    case .claude:
                        Picker("Model", selection: $settings.selectedClaudeModel) {
                            ForEach(ClaudeModel.allCases) { model in
                                Text(model.displayName).tag(model)
                            }
                        }
                    }
                } header: {
                    Text("Model")
                } footer: {
                    if !settings.currentModel.supportsVision {
                        Label("This model does not support image scanning", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    }
                }

                Section {
                    SecureField("API Key", text: $apiKeyInput)
                        .textContentType(.password)
                        .onChange(of: apiKeyInput) { validationResult = nil }

                    Button {
                        Task { await saveAndValidate() }
                    } label: {
                        HStack {
                            if isValidating {
                                ProgressView().controlSize(.small)
                                Text("Validating...")
                            } else {
                                Text("Save & Test")
                            }
                        }
                    }
                    .disabled(apiKeyInput.isEmpty || isValidating)
                } header: {
                    Text("\(settings.selectedProvider.rawValue) API Key")
                } footer: {
                    validationFooter
                }

                Section("Status") {
                    LabeledContent("Version", value: "1.0.0 (MVP)")
                    if settings.isConfigured {
                        HStack {
                            Text("Status")
                            Spacer()
                            Label("Ready", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }
                    } else {
                        HStack {
                            Text("Status")
                            Spacer()
                            Label("API key required", systemImage: "exclamationmark.circle.fill")
                                .foregroundStyle(.orange)
                        }
                    }
                }

                Section("Data Management") {
                    Button {
                        showingExportSheet = true
                    } label: {
                        Label("Export Data", systemImage: "square.and.arrow.up")
                    }

                    Button {
                        showingImportPicker = true
                    } label: {
                        Label("Import Data", systemImage: "square.and.arrow.down")
                    }

                    Button("Restore Default Tags") {
                        showingRestoreTagsAlert = true
                    }
                }
            }
            .alert("Restore Default Tags?", isPresented: $showingRestoreTagsAlert) {
                Button("Add Missing", role: .none) { restoreDefaultTags(reset: false) }
                Button("Reset All", role: .destructive) { restoreDefaultTags(reset: true) }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("'Add Missing' adds any default tags you've deleted. 'Reset All' removes all tags and recreates defaults.")
            }
            .sheet(isPresented: $showingExportSheet) {
                ExportDataSheet(context: context)
            }
            .fileImporter(
                isPresented: $showingImportPicker,
                allowedContentTypes: [.json],
                allowsMultipleSelection: false
            ) { result in
                handleImportFile(result)
            }
            .sheet(isPresented: $showingImportSheet) {
                if let data = importData, let preview = importPreview {
                    ImportDataSheet(
                        data: data,
                        preview: preview,
                        context: context
                    ) { result in
                        importResult = result
                        showingImportSheet = false
                    }
                }
            }
            .alert("Import Complete", isPresented: .constant(importResult != nil)) {
                Button("OK") { importResult = nil }
            } message: {
                Text(importResult?.summary ?? "")
            }
            .alert("Import Error", isPresented: .constant(importError != nil)) {
                Button("OK") { importError = nil }
            } message: {
                Text(importError ?? "")
            }
            .navigationTitle("Settings")
            .onAppear {
                apiKeyInput = settings.currentAPIKey
            }
        }
    }

    @ViewBuilder
    private var validationFooter: some View {
        if let result = validationResult {
            switch result {
            case .success:
                Label("API key is valid", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            case .error(let message):
                Label(message, systemImage: "xmark.circle.fill")
                    .foregroundStyle(.red)
            }
        } else if !apiKeyInput.isEmpty && apiKeyInput != settings.currentAPIKey {
            Text("Tap 'Save & Test' to validate your API key")
        }
    }

    private func saveAndValidate() async {
        isValidating = true
        validationResult = nil

        let service: LLMService
        switch settings.selectedProvider {
        case .openai: service = OpenAIService(apiKey: apiKeyInput, model: settings.selectedOpenAIModel)
        case .claude: service = ClaudeService(apiKey: apiKeyInput, model: settings.selectedClaudeModel)
        }

        do {
            try await service.validateAPIKey()
            switch settings.selectedProvider {
            case .openai: settings.openaiAPIKey = apiKeyInput
            case .claude: settings.claudeAPIKey = apiKeyInput
            }
            validationResult = .success
        } catch let error as LLMError {
            validationResult = .error(error.errorDescription ?? "Validation failed")
        } catch {
            validationResult = .error("Network error: \(error.localizedDescription)")
        }
        isValidating = false
    }

    private func restoreDefaultTags(reset: Bool) {
        let manager = DefaultDataManager(modelContext: context)
        if reset {
            manager.resetTagsToDefaults()
        } else {
            manager.restoreDefaultTags()
        }
    }

    private func handleImportFile(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            guard url.startAccessingSecurityScopedResource() else {
                importError = "Cannot access the selected file"
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }

            do {
                let data = try Data(contentsOf: url)
                let service = DataExportService(modelContext: context)
                let preview = try service.previewImport(from: data)

                if preview.hasData {
                    importData = data
                    importPreview = preview
                    showingImportSheet = true
                } else {
                    importError = "The file contains no data to import"
                }
            } catch {
                importError = "Failed to read file: \(error.localizedDescription)"
            }
        case .failure(let error):
            importError = "Failed to select file: \(error.localizedDescription)"
        }
    }
}

// MARK: - Export Data Sheet

struct ExportDataSheet: View {
    @Environment(\.dismiss) private var dismiss
    let context: ModelContext

    @State private var selectedTypes: Set<ExportDataType> = Set(ExportDataType.allCases)
    @State private var isExporting = false
    @State private var exportedFileURL: URL?
    @State private var showingShareSheet = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Select Data to Export") {
                    ForEach(ExportDataType.allCases) { type in
                        Toggle(isOn: binding(for: type)) {
                            Label(type.rawValue, systemImage: type.icon)
                        }
                    }
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Export Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Export") { exportData() }
                        .disabled(selectedTypes.isEmpty || isExporting)
                }
            }
            .sheet(isPresented: $showingShareSheet) {
                if let url = exportedFileURL {
                    ShareSheet(items: [url])
                }
            }
        }
    }

    private func binding(for type: ExportDataType) -> Binding<Bool> {
        Binding(
            get: { selectedTypes.contains(type) },
            set: { isSelected in
                if isSelected {
                    selectedTypes.insert(type)
                } else {
                    selectedTypes.remove(type)
                }
            }
        )
    }

    private func exportData() {
        isExporting = true
        errorMessage = nil

        do {
            let service = DataExportService(modelContext: context)
            let data = try service.exportData(types: selectedTypes)

            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let filename = "ProjectX-Export-\(dateFormatter.string(from: Date())).json"

            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
            try data.write(to: tempURL)

            exportedFileURL = tempURL
            showingShareSheet = true
        } catch {
            errorMessage = "Export failed: \(error.localizedDescription)"
        }

        isExporting = false
    }
}

// MARK: - Import Data Sheet

struct ImportDataSheet: View {
    @Environment(\.dismiss) private var dismiss
    let data: Data
    let preview: ImportPreview
    let context: ModelContext
    let onComplete: (ImportResult) -> Void

    @State private var selectedTypes: Set<ExportDataType> = []
    @State private var isImporting = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                if let date = preview.exportDate {
                    Section {
                        LabeledContent("Export Date", value: date.formatted(date: .abbreviated, time: .shortened))
                    }
                }

                Section("Select Data to Import") {
                    if preview.tagsCount > 0 {
                        Toggle(isOn: binding(for: .tags)) {
                            Label("\(preview.tagsCount) Tags", systemImage: ExportDataType.tags.icon)
                        }
                    }
                    if preview.foodsCount > 0 {
                        Toggle(isOn: binding(for: .foods)) {
                            Label("\(preview.foodsCount) Foods", systemImage: ExportDataType.foods.icon)
                        }
                    }
                    if preview.tripsCount > 0 {
                        Toggle(isOn: binding(for: .trips)) {
                            Label("\(preview.tripsCount) Trips", systemImage: ExportDataType.trips.icon)
                        }
                    }
                }

                Section {
                    Text("Existing items with the same name will be replaced.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let error = errorMessage {
                    Section {
                        Text(error).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Import Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Import") { importData() }
                        .disabled(selectedTypes.isEmpty || isImporting)
                }
            }
            .onAppear {
                // Pre-select all available types
                if preview.tagsCount > 0 { selectedTypes.insert(.tags) }
                if preview.foodsCount > 0 { selectedTypes.insert(.foods) }
                if preview.tripsCount > 0 { selectedTypes.insert(.trips) }
            }
        }
    }

    private func binding(for type: ExportDataType) -> Binding<Bool> {
        Binding(
            get: { selectedTypes.contains(type) },
            set: { isSelected in
                if isSelected {
                    selectedTypes.insert(type)
                } else {
                    selectedTypes.remove(type)
                }
            }
        )
    }

    private func importData() {
        isImporting = true
        errorMessage = nil

        do {
            let service = DataExportService(modelContext: context)
            let result = try service.importData(from: data, types: selectedTypes)
            onComplete(result)
        } catch {
            errorMessage = "Import failed: \(error.localizedDescription)"
            isImporting = false
        }
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
