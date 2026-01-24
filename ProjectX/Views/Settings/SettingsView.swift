import SwiftUI
import SwiftData

struct SettingsView: View {
    @Bindable var settings: AppSettings
    @Environment(\.modelContext) private var context

    @State private var apiKeyInput = ""
    @State private var isValidating = false
    @State private var validationResult: ValidationResult?
    @State private var showingRestoreTagsAlert = false

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
                        // Load the current key for the selected provider
                        apiKeyInput = settings.currentAPIKey
                        validationResult = nil
                    }
                } header: {
                    Text("LLM Provider")
                } footer: {
                    Text("Select the AI service to use for receipt scanning")
                }

                Section {
                    SecureField("API Key", text: $apiKeyInput)
                        .textContentType(.password)
                        .onChange(of: apiKeyInput) {
                            validationResult = nil
                        }

                    Button {
                        Task { await saveAndValidate() }
                    } label: {
                        HStack {
                            if isValidating {
                                ProgressView()
                                    .controlSize(.small)
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

        // Create a temporary service with the input key to validate
        let service: LLMService
        switch settings.selectedProvider {
        case .openai:
            service = OpenAIService(apiKey: apiKeyInput)
        case .claude:
            service = ClaudeService(apiKey: apiKeyInput)
        }

        do {
            try await service.validateAPIKey()

            // Key is valid - save it
            switch settings.selectedProvider {
            case .openai:
                settings.openaiAPIKey = apiKeyInput
            case .claude:
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

    private func restoreDefaultTags(reset: Bool) {
        let manager = DefaultDataManager(modelContext: context)
        if reset {
            manager.resetTagsToDefaults()
        } else {
            manager.restoreDefaultTags()
        }
    }
}
