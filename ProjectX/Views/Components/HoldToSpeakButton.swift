import SwiftUI
import Speech
import AVFoundation

struct HoldToSpeakButton: View {
    let mode: QuickAddMode
    let settings: AppSettings
    let foods: [Food]
    let onProcessing: (String) -> Void
    let onComplete: (String?) -> Void
    let onTripItems: ((_ items: [PurchasedItem], _ storeName: String?, _ date: Date?) -> Void)?
    let onMealItems: ((_ items: [MealItem], _ date: Date?) -> Void)?
    let onFoodData: ((_ name: String, _ category: FoodCategory, _ nutrition: NutritionInfo?) -> Void)?

    @State private var isRecording = false
    @State private var permissionDenied = false
    @State private var permissionChecked = false
    @State private var transcribedText = ""
    @GestureState private var isPressed = false

    @State private var speechRecognizer: SFSpeechRecognizer?
    @State private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    @State private var recognitionTask: SFSpeechRecognitionTask?
    @State private var audioEngine: AVAudioEngine?

    var body: some View {
        VStack(spacing: 8) {
            if permissionDenied {
                Button { openAppSettings() } label: {
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
                    .fill(isRecording ? Color.red : Color.themePrimary)
                    .frame(width: 72, height: 72)
                    .overlay {
                        Image(systemName: isRecording ? "waveform" : "mic.fill")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(.white)
                            .symbolEffect(.variableColor.iterative, isActive: isRecording)
                    }
                    .shadow(color: (isRecording ? Color.red : Color.themePrimary).opacity(0.4), radius: 8, y: 4)
                    .scaleEffect(isPressed ? 1.1 : 1.0)
                    .animation(.spring(response: 0.3), value: isPressed)
                    .gesture(
                        LongPressGesture(minimumDuration: 0.1)
                            .updating($isPressed) { value, state, _ in
                                state = value
                            }
                            .onChanged { _ in
                                if !isRecording { startRecording() }
                            }
                            .onEnded { _ in
                                stopRecordingAndProcess()
                            }
                    )
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 0)
                            .onEnded { _ in
                                if isRecording { stopRecordingAndProcess() }
                            }
                    )
            }

            if permissionDenied {
                Button { openAppSettings() } label: {
                    Text("Mic access required")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
            } else {
                Text(isRecording ? "Release" : "Hold to speak")
                    .font(.caption)
                    .foregroundStyle(isRecording ? .red : .secondary)
            }
        }
        .onAppear { checkPermissions() }
        .onDisappear { stopRecording() }
    }

    private func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    private func checkPermissions() {
        guard !permissionChecked else { return }

        SFSpeechRecognizer.requestAuthorization { status in
            Task { @MainActor in
                if status != .authorized { permissionDenied = true }
                permissionChecked = true
            }
        }

        Task {
            let granted = await AVAudioApplication.requestRecordPermission()
            await MainActor.run {
                if !granted { permissionDenied = true }
            }
        }
    }

    private func startRecording() {
        transcribedText = ""

        if speechRecognizer == nil {
            speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        }
        if audioEngine == nil {
            audioEngine = AVAudioEngine()
        }

        guard let recognizer = speechRecognizer, recognizer.isAvailable,
              let engine = audioEngine else { return }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch { return }

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let request = recognitionRequest else { return }
        request.shouldReportPartialResults = true

        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        guard format.sampleRate > 0 else { return }

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }

        engine.prepare()
        do { try engine.start() } catch { return }
        isRecording = true

        recognitionTask = recognizer.recognitionTask(with: request) { result, error in
            Task { @MainActor in
                if let result = result {
                    transcribedText = result.bestTranscription.formattedString
                }
                if error != nil || result?.isFinal == true {
                    stopRecording()
                }
            }
        }
    }

    private func stopRecording() {
        guard isRecording else { return }

        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
        isRecording = false

        try? AVAudioSession.sharedInstance().setActive(false)
    }

    private func stopRecordingAndProcess() {
        stopRecording()

        let textToProcess = transcribedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !textToProcess.isEmpty else { return }

        Task {
            await processVoiceInput(textToProcess)
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
