import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct SettingsView: View {
    @Bindable var settings: AppSettings
    @Environment(\.modelContext) private var context
    @Query(sort: \Profile.createdAt) private var profiles: [Profile]

    @State private var apiKeyInput = ""
    @State private var isValidating = false
    @State private var validationResult: ValidationResult?
    @State private var showingRestoreTagsAlert = false
    @State private var showingExportSheet = false
    @State private var showingImportPicker = false
    @State private var showingImportSheet = false
    @State private var importData: Data?
    @State private var importPreview: ImportPreview?
    @State private var showingImportResult = false
    @State private var importResultMessage = ""
    @State private var showingImportError = false
    @State private var importErrorMessage = ""
    @State private var showingNutritionTargetSheet = false
    @State private var showingFamilyGuide = false

    enum ValidationResult { case success, error(String) }

    private var activeProfileName: String {
        profiles.first { $0.id == settings.activeProfileId }?.name ?? "Default"
    }

    var body: some View {
        NavigationStack {
            Form {
                providerSection
                modelSection
                apiKeySection
                nutritionTargetSection
                scanPreferencesSection
                statusSection
                dataManagementSection
            }
            .navigationTitle("Settings")
            .onAppear { apiKeyInput = settings.currentAPIKey }
            .alert("Restore Default Tags?", isPresented: $showingRestoreTagsAlert) {
                Button("Add Missing") { DefaultDataManager(modelContext: context).restoreDefaultTags() }
                Button("Reset All", role: .destructive) { DefaultDataManager(modelContext: context).resetTagsToDefaults() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("'Add Missing' adds any default tags you've deleted. 'Reset All' removes all tags and recreates defaults.")
            }
            .sheet(isPresented: $showingExportSheet) {
                ExportDataSheet(context: context, settings: settings, profileName: activeProfileName)
            }
            .fileImporter(isPresented: $showingImportPicker, allowedContentTypes: [.json], allowsMultipleSelection: false) { result in
                handleImportFile(result)
            }
            .sheet(isPresented: $showingImportSheet) {
                if let data = importData, let preview = importPreview {
                    ImportDataSheet(data: data, preview: preview, context: context, settings: settings, profileName: activeProfileName) { result in
                        importResultMessage = result.summary
                        showingImportResult = true
                        showingImportSheet = false
                    }
                }
            }
            .alert("Import Complete", isPresented: $showingImportResult) {
                Button("OK") {}
            } message: {
                Text(importResultMessage)
            }
            .alert("Import Error", isPresented: $showingImportError) {
                Button("OK") {}
            } message: {
                Text(importErrorMessage)
            }
            .sheet(isPresented: $showingNutritionTargetSheet) {
                NutritionTargetSheet(target: nutritionTargetBinding)
            }
            .sheet(isPresented: $showingFamilyGuide) {
                FamilyGuideView(settings: settings)
            }
        }
    }

    // MARK: - Sections

    private var providerSection: some View {
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
            Text("Select the AI provider for receipt scanning and nutrition estimation.")
        }
    }

    private var modelSection: some View {
        Section {
            modelPicker
        } header: {
            Text("Model")
        } footer: {
            if !settings.currentModel.supportsVision {
                Label("This model does not support image scanning", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(Color.themeWarning)
            }
        }
    }

    @ViewBuilder
    private var modelPicker: some View {
        switch settings.selectedProvider {
        case .openai:
            Picker("Model", selection: $settings.selectedOpenAIModel) {
                Section("GPT-4.1") {
                    ForEach([OpenAIModel.gpt41, .gpt41Mini, .gpt41Nano], id: \.self) { model in
                        Text(model.displayName).tag(model)
                    }
                }
                Section("GPT-4o") {
                    ForEach([OpenAIModel.gpt4o, .gpt4oMini], id: \.self) { model in
                        Text(model.displayName).tag(model)
                    }
                }
                Section("Reasoning") {
                    ForEach([OpenAIModel.o4Mini, .o3Mini], id: \.self) { model in
                        Text(model.displayName).tag(model)
                    }
                }
            }
        case .claude:
            Picker("Model", selection: $settings.selectedClaudeModel) {
                Section("Claude 4") {
                    ForEach([ClaudeModel.sonnet4, .opus4], id: \.self) { model in
                        Text(model.displayName).tag(model)
                    }
                }
                Section("Claude 3.5") {
                    ForEach([ClaudeModel.haiku35, .sonnet35], id: \.self) { model in
                        Text(model.displayName).tag(model)
                    }
                }
            }
        }
    }

    private var apiKeySection: some View {
        Section {
            SecureField("Enter your API key", text: $apiKeyInput)
                .textContentType(.password)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .onChange(of: apiKeyInput) { validationResult = nil }
            Button {
                Task { await saveAndValidate() }
            } label: {
                HStack {
                    Spacer()
                    if isValidating {
                        ProgressView().controlSize(.small)
                        Text("Validating...")
                    } else {
                        Label("Save & Test", systemImage: "checkmark.shield")
                    }
                    Spacer()
                }
            }
            .disabled(apiKeyInput.isEmpty || isValidating)
        } header: {
            Text("\(settings.selectedProvider.rawValue) API Key")
        } footer: {
            VStack(alignment: .leading, spacing: 4) {
                validationFooter
                if validationResult == nil && apiKeyInput.isEmpty {
                    Text("Get your API key from \(settings.selectedProvider == .openai ? "platform.openai.com" : "console.anthropic.com")")
                        .font(.caption)
                }
            }
        }
    }

    @ViewBuilder
    private var validationFooter: some View {
        if let result = validationResult {
            switch result {
            case .success:
                Label("API key is valid", systemImage: "checkmark.circle.fill").foregroundStyle(Color.themeSuccess)
            case .error(let msg):
                Label(msg, systemImage: "xmark.circle.fill").foregroundStyle(Color.themeError)
            }
        } else if !apiKeyInput.isEmpty && apiKeyInput != settings.currentAPIKey {
            Text("Tap 'Save & Test' to validate your API key")
        }
    }

    private var statusSection: some View {
        Section("Status") {
            LabeledContent("Version", value: "1.0.0 (MVP)")
            HStack {
                Text("Status")
                Spacer()
                if settings.isConfigured {
                    Label("Ready", systemImage: "checkmark.circle.fill").foregroundStyle(Color.themeSuccess)
                } else {
                    Label("API key required", systemImage: "exclamationmark.circle.fill").foregroundStyle(Color.themeWarning)
                }
            }
        }
    }

    private var currentNutritionTarget: NutritionTarget {
        if let profileId = settings.activeProfileId {
            return settings.nutritionTarget(for: profileId)
        }
        return settings.dailyNutritionTarget
    }

    private var currentMembers: [FamilyMember] {
        if let profileId = settings.activeProfileId {
            return settings.familyMembers(for: profileId)
        }
        return settings.familyMembers
    }

    private var hasCompletedGuide: Bool {
        if let profileId = settings.activeProfileId {
            return settings.hasCompletedFamilyGuide(for: profileId)
        }
        return settings.hasCompletedFamilyGuide
    }

    private var nutritionTargetBinding: Binding<NutritionTarget> {
        Binding(
            get: { currentNutritionTarget },
            set: { newValue in
                if let profileId = settings.activeProfileId {
                    settings.setNutritionTarget(newValue, for: profileId)
                } else {
                    settings.dailyNutritionTarget = newValue
                }
            }
        )
    }

    private var nutritionTargetSection: some View {
        Section {
            Button { showingFamilyGuide = true } label: {
                HStack {
                    Label("Nutrition Guide", systemImage: "sparkles")
                    Spacer()
                    if hasCompletedGuide {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.themeSuccess)
                    } else {
                        Text("Set Up").foregroundStyle(.secondary)
                    }
                }
            }
            Button { showingNutritionTargetSheet = true } label: {
                HStack {
                    Label("Manual Target", systemImage: "slider.horizontal.3")
                    Spacer()
                    Text("\(Int(currentNutritionTarget.calories)) kcal").foregroundStyle(.secondary)
                }
            }
            if !currentMembers.isEmpty {
                HStack {
                    Text("Members")
                    Spacer()
                    Text(currentMembers.map(\.name).joined(separator: ", ")).foregroundStyle(.secondary).lineLimit(1)
                }
            }
        } header: {
            Text("Nutrition Goals")
        } footer: {
            Text("Use the guide for AI-powered targets based on your household, or set targets manually.")
        }
    }

    private var scanPreferencesSection: some View {
        Section {
            Toggle("Filter Baby Food", isOn: $settings.filterBabyFood)
        } header: {
            Text("Scan Preferences")
        } footer: {
            Text("When enabled, baby food and infant formula will be excluded from receipt scans.")
        }
    }

    private var dataManagementSection: some View {
        Section("Data Management") {
            NavigationLink {
                ProfilesView(settings: settings)
            } label: {
                Label("Profiles", systemImage: "person.2")
            }
            NavigationLink {
                TagCategoryManagementView()
            } label: {
                Label("Tags & Categories", systemImage: "tag")
            }
            Button { showingExportSheet = true } label: {
                Label("Export Data", systemImage: "square.and.arrow.up")
            }
            Button { showingImportPicker = true } label: {
                Label("Import Data", systemImage: "square.and.arrow.down")
            }
            Button("Restore Default Tags") { showingRestoreTagsAlert = true }
        }
    }

    // MARK: - Actions

    private func saveAndValidate() async {
        isValidating = true
        validationResult = nil
        let service: LLMService = settings.selectedProvider == .openai
            ? OpenAIService(apiKey: apiKeyInput, model: settings.selectedOpenAIModel)
            : ClaudeService(apiKey: apiKeyInput, model: settings.selectedClaudeModel)
        do {
            try await service.validateAPIKey()
            if settings.selectedProvider == .openai {
                settings.openaiAPIKey = apiKeyInput
            } else {
                settings.claudeAPIKey = apiKeyInput
            }
            validationResult = .success
        } catch let error as LLMError {
            validationResult = .error(error.errorDescription ?? "Validation failed")
        } catch {
            validationResult = .error("Network error: \(error.localizedDescription)")
        }
        isValidating = false
    }

    private func handleImportFile(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first, url.startAccessingSecurityScopedResource() else {
                importErrorMessage = "Cannot access the selected file"
                showingImportError = true
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }
            do {
                let data = try Data(contentsOf: url)
                let preview = try DataExportService(modelContext: context, profileId: settings.activeProfileId).previewImport(from: data)
                if preview.hasData {
                    importData = data
                    importPreview = preview
                    showingImportSheet = true
                } else {
                    importErrorMessage = "The file contains no data to import"
                    showingImportError = true
                }
            } catch {
                importErrorMessage = "Failed to read file: \(error.localizedDescription)"
                showingImportError = true
            }
        case .failure(let error):
            importErrorMessage = "Failed to select file: \(error.localizedDescription)"
            showingImportError = true
        }
    }
}
