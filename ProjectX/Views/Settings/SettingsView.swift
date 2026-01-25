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

    var body: some View {
        NavigationStack {
            Form {
                providerSection
                modelSection
                apiKeySection
                nutritionTargetSection
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
                ExportDataSheet(context: context)
            }
            .fileImporter(isPresented: $showingImportPicker, allowedContentTypes: [.json], allowsMultipleSelection: false) { result in
                handleImportFile(result)
            }
            .sheet(isPresented: $showingImportSheet) {
                if let data = importData, let preview = importPreview {
                    ImportDataSheet(data: data, preview: preview, context: context) { result in
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
                    .foregroundStyle(.orange)
            }
        }
    }

    @ViewBuilder
    private var modelPicker: some View {
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

    private var nutritionTargetSection: some View {
        Section {
            Button { showingFamilyGuide = true } label: {
                HStack {
                    Label("Family Nutrition Guide", systemImage: "sparkles")
                    Spacer()
                    if settings.hasCompletedFamilyGuide {
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
                    Text("\(Int(settings.dailyNutritionTarget.calories)) kcal").foregroundStyle(.secondary)
                }
            }
            if !settings.familyMembers.isEmpty {
                HStack {
                    Text("Family Members")
                    Spacer()
                    Text(settings.familyMembers.map(\.name).joined(separator: ", ")).foregroundStyle(.secondary).lineLimit(1)
                }
            }
        } header: {
            Text("Family Goals")
        } footer: {
            Text("Use the guide for AI-powered targets based on your family, or set targets manually.")
        }
        .sheet(isPresented: $showingNutritionTargetSheet) {
            NutritionTargetSheet(target: $settings.dailyNutritionTarget)
        }
        .sheet(isPresented: $showingFamilyGuide) {
            FamilyGuideView(settings: settings)
        }
    }

    private var dataManagementSection: some View {
        Section("Data Management") {
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
                let preview = try DataExportService(modelContext: context).previewImport(from: data)
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

// MARK: - Set Toggle Binding Helper

private func setToggleBinding<T: Hashable>(for item: T, in set: Binding<Set<T>>) -> Binding<Bool> {
    Binding(
        get: { set.wrappedValue.contains(item) },
        set: { if $0 { set.wrappedValue.insert(item) } else { set.wrappedValue.remove(item) } }
    )
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
                        Toggle(isOn: setToggleBinding(for: type, in: $selectedTypes)) {
                            Label(type.rawValue, systemImage: type.icon)
                        }
                    }
                }
                if let error = errorMessage {
                    Section { Text(error).foregroundStyle(.red) }
                }
            }
            .navigationTitle("Export Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Export") { exportData() }.disabled(selectedTypes.isEmpty || isExporting)
                }
            }
            .sheet(isPresented: $showingShareSheet) {
                if let url = exportedFileURL { ShareSheet(items: [url]) }
            }
        }
    }

    private func exportData() {
        isExporting = true
        errorMessage = nil
        do {
            let data = try DataExportService(modelContext: context).exportData(types: selectedTypes)
            let filename = "ProjectX-Export-\(Date().formatted(.dateTime.year().month().day())).json"
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
            try data.write(to: tempURL)
            exportedFileURL = tempURL
            showingShareSheet = true
        } catch { errorMessage = "Export failed: \(error.localizedDescription)" }
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
                    Section { LabeledContent("Export Date", value: date.formatted(date: .abbreviated, time: .shortened)) }
                }
                Section("Select Data to Import") {
                    if preview.tagsCount > 0 {
                        Toggle(isOn: setToggleBinding(for: .tags, in: $selectedTypes)) {
                            Label("\(preview.tagsCount) Tags", systemImage: ExportDataType.tags.icon)
                        }
                    }
                    if preview.foodsCount > 0 {
                        Toggle(isOn: setToggleBinding(for: .foods, in: $selectedTypes)) {
                            Label("\(preview.foodsCount) Foods", systemImage: ExportDataType.foods.icon)
                        }
                    }
                    if preview.tripsCount > 0 {
                        Toggle(isOn: setToggleBinding(for: .trips, in: $selectedTypes)) {
                            Label("\(preview.tripsCount) Trips", systemImage: ExportDataType.trips.icon)
                        }
                    }
                }
                Section { Text("Existing items with the same name will be replaced.").font(.caption).foregroundStyle(.secondary) }
                if let error = errorMessage {
                    Section { Text(error).foregroundStyle(.red) }
                }
            }
            .navigationTitle("Import Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Import") { importData() }.disabled(selectedTypes.isEmpty || isImporting)
                }
            }
            .onAppear {
                if preview.tagsCount > 0 { selectedTypes.insert(.tags) }
                if preview.foodsCount > 0 { selectedTypes.insert(.foods) }
                if preview.tripsCount > 0 { selectedTypes.insert(.trips) }
            }
        }
    }

    private func importData() {
        isImporting = true
        errorMessage = nil
        do {
            let result = try DataExportService(modelContext: context).importData(from: data, types: selectedTypes)
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

// MARK: - Nutrition Target Sheet

private struct TargetFields {
    var protein, carbohydrates, fat, sugar, fiber, sodium: String

    var calculatedCalories: Int {
        let p = (Double(protein) ?? 0) * 4
        let c = (Double(carbohydrates) ?? 0) * 4
        let f = (Double(fat) ?? 0) * 9
        return Int(p + c + f)
    }

    init(from target: NutritionTarget) {
        protein = String(Int(target.protein)); carbohydrates = String(Int(target.carbohydrates))
        fat = String(Int(target.fat)); sugar = String(Int(target.sugar))
        fiber = String(Int(target.fiber)); sodium = String(Int(target.sodium))
    }

    init(from level: ActivityLevel) {
        let b = level.baseline
        protein = "\(b.pro)"; carbohydrates = "\(b.carb)"; fat = "\(b.fat)"
        sugar = "25"; fiber = "25"; sodium = "2300"
    }

    func toTarget() -> NutritionTarget {
        NutritionTarget(calories: Double(calculatedCalories), protein: Double(protein) ?? 50,
            carbohydrates: Double(carbohydrates) ?? 250, fat: Double(fat) ?? 65,
            sugar: Double(sugar) ?? 50, fiber: Double(fiber) ?? 25, sodium: Double(sodium) ?? 2300)
    }
}

struct NutritionTargetSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var target: NutritionTarget
    @State private var fields: TargetFields
    @State private var activity: ActivityLevel = .moderate

    init(target: Binding<NutritionTarget>) {
        _target = target
        _fields = State(initialValue: TargetFields(from: target.wrappedValue))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Activity Level", selection: $activity) {
                        ForEach(ActivityLevel.allCases) { Text($0.rawValue).tag($0) }
                    }
                    Text(activity.description).font(.caption).foregroundStyle(.secondary)
                    Button("Apply Baseline for 60kg Adult") { fields = TargetFields(from: activity) }
                        .foregroundStyle(Color.themePrimary)
                } header: { Text("Reference Baseline") } footer: {
                    let b = activity.baseline
                    Text("60kg adult: \(b.cal) kcal, \(b.pro)g protein, \(b.carb)g carbs, \(b.fat)g fat")
                }

                Section {
                    HStack {
                        Text("Calories").fontWeight(.medium)
                        Spacer()
                        Text("\(fields.calculatedCalories)").foregroundStyle(.secondary).frame(width: 80, alignment: .trailing)
                        Text("kcal").foregroundStyle(.tertiary).frame(width: 40, alignment: .leading)
                    }
                    .listRowBackground(Color(.secondarySystemBackground))
                    TargetRow("Protein", $fields.protein, "g", hint: "4 kcal/g")
                    TargetRow("Carbohydrates", $fields.carbohydrates, "g", hint: "4 kcal/g")
                    TargetRow("Fat", $fields.fat, "g", hint: "9 kcal/g")
                } header: { Text("Daily Macros") } footer: {
                    Text("Calories = (Protein × 4) + (Carbs × 4) + (Fat × 9)")
                }

                Section("Daily Limits") {
                    TargetRow("Sugar", $fields.sugar, "g")
                    TargetRow("Fiber", $fields.fiber, "g")
                    TargetRow("Sodium", $fields.sodium, "mg")
                }
            }
            .navigationTitle("Nutrition Targets")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { target = fields.toTarget(); dismiss() } }
            }
        }
    }
}

private struct TargetRow: View {
    let label: String, unit: String, hint: String?
    @Binding var value: String

    init(_ label: String, _ value: Binding<String>, _ unit: String, hint: String? = nil) {
        self.label = label; self._value = value; self.unit = unit; self.hint = hint
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                if let hint { Text(hint).font(.caption2).foregroundStyle(.tertiary) }
            }
            Spacer()
            TextField("0", text: $value).keyboardType(.numberPad).multilineTextAlignment(.trailing).frame(width: 80)
            Text(unit).foregroundStyle(.secondary).frame(width: 40, alignment: .leading)
        }
    }
}
