import SwiftUI

struct SettingsView: View {
    @State private var settings = AppSettings()

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Provider", selection: $settings.selectedProvider) {
                        ForEach(LLMProvider.allCases) { provider in
                            Text(provider.rawValue).tag(provider)
                        }
                    }
                } header: {
                    Text("LLM Provider")
                } footer: {
                    Text("Select the AI service to use for receipt scanning (coming soon)")
                }

                Section {
                    SecureField("OpenAI API Key", text: $settings.openaiAPIKey)
                        .textContentType(.password)
                } header: {
                    Text("OpenAI")
                } footer: {
                    if settings.selectedProvider == .openai {
                        Text("Currently selected provider")
                    }
                }

                Section {
                    SecureField("Claude API Key", text: $settings.claudeAPIKey)
                        .textContentType(.password)
                } header: {
                    Text("Claude (Anthropic)")
                } footer: {
                    if settings.selectedProvider == .claude {
                        Text("Currently selected provider")
                    }
                }

                Section("About") {
                    LabeledContent("Version", value: "1.0.0 (MVP)")
                    if settings.isConfigured {
                        LabeledContent("Status", value: "Ready")
                    } else {
                        LabeledContent("Status", value: "API key required")
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
}
