import SwiftUI

struct HoldToSpeakButton: View {
    let mode: QuickAddMode
    let settings: AppSettings
    let foods: [Food]
    let onProcessing: (String) -> Void
    let onComplete: (String?) -> Void
    let onTripItems: ((_ items: [PurchasedItem], _ storeName: String?, _ date: Date?) -> Void)?
    let onMealItems: ((_ items: [MealItem], _ date: Date?) -> Void)?
    let onFoodData: ((_ name: String, _ category: FoodCategory, _ nutrition: NutritionInfo?) -> Void)?

    @State private var engine = SpeechRecognitionEngine()

    var body: some View {
        VStack(spacing: 8) {
            if engine.permissionDenied {
                Button { SpeechRecognitionEngine.openAppSettings() } label: {
                    Circle()
                        .fill(Color(.systemGray4))
                        .frame(width: 72, height: 72)
                        .overlay {
                            Image(systemName: "mic.slash.fill")
                                .font(.system(size: 28, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                }
                .buttonStyle(.plain)
            } else {
                Circle()
                    .fill(engine.isRecording ? Color.red : Color.themePrimary)
                    .frame(width: 72, height: 72)
                    .overlay {
                        Image(systemName: engine.isRecording ? "waveform" : "mic.fill")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(.white)
                            .symbolEffect(.variableColor.iterative, isActive: engine.isRecording)
                    }
                    .shadow(color: (engine.isRecording ? Color.red : Color.themePrimary).opacity(0.4), radius: 8, y: 4)
                    .scaleEffect(engine.isRecording ? 1.1 : 1.0)
                    .animation(.spring(response: 0.3), value: engine.isRecording)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { _ in
                                if !engine.isRecording && !engine.permissionDenied {
                                    engine.startRecording()
                                }
                            }
                            .onEnded { _ in
                                if engine.isRecording {
                                    stopRecordingAndProcess()
                                }
                            }
                    )
            }

            if engine.permissionDenied {
                Button { SpeechRecognitionEngine.openAppSettings() } label: {
                    Text("Mic access required")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
            } else if engine.isRecording && !engine.transcribedText.isEmpty {
                Text(engine.transcribedText)
                    .font(.caption)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .frame(maxWidth: 200)
                    .multilineTextAlignment(.center)
            } else {
                Text(engine.isRecording ? "Listening..." : "Hold to speak")
                    .font(.caption)
                    .foregroundStyle(engine.isRecording ? .red : .secondary)
            }
        }
        .onAppear { engine.checkPermissions() }
        .onDisappear { engine.stopRecording() }
    }

    private func stopRecordingAndProcess() {
        engine.stopRecordingWithMinimumDuration { text in
            guard let text else { return }
            Task { await processVoiceInput(text) }
        }
    }

    private func processVoiceInput(_ text: String) async {
        guard settings.isConfigured else {
            onComplete("Please configure your API key in Settings first")
            return
        }

        onProcessing("Processing...")

        guard let service = LLMServiceFactory.create(settings: settings) else {
            onComplete("Failed to create AI service")
            return
        }

        do {
            switch mode {
            case .trip, .meal:
                let receipt = try await service.extractReceipt(from: text, filterBabyFood: settings.filterBabyFood)
                guard !receipt.items.isEmpty else {
                    onComplete("Couldn't identify any items")
                    return
                }
                onComplete(nil)
                if mode == .trip {
                    onTripItems?(ItemMapper.mapToTripItems(receipt.items, foods: foods), receipt.storeName, receipt.parsedDate)
                } else {
                    onMealItems?(ItemMapper.mapToMealItems(receipt.items, foods: foods), receipt.parsedDate)
                }

            case .food:
                let (foodName, category, nutrition) = try await ItemMapper.prepareFoodData(from: text, service: service)
                onComplete(nil)
                onFoodData?(foodName, category, nutrition)
            }
        } catch {
            onComplete("Failed to process: \(error.localizedDescription)")
        }
    }
}
