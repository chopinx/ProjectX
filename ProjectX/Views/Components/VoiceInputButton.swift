import SwiftUI
import Speech
import AVFoundation

struct VoiceInputButton: View {
    @Binding var text: String
    @State private var isRecording = false
    @State private var permissionDenied = false
    @State private var permissionChecked = false

    // Use lazy initialization to avoid crashes
    @State private var speechRecognizer: SFSpeechRecognizer?
    @State private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    @State private var recognitionTask: SFSpeechRecognitionTask?
    @State private var audioEngine: AVAudioEngine?

    var body: some View {
        Button {
            isRecording ? stopRecording() : startRecording()
        } label: {
            Image(systemName: isRecording ? "stop.circle.fill" : "mic.circle.fill")
                .font(.title)
                .foregroundStyle(isRecording ? .red : Color.themePrimary)
                .symbolEffect(.pulse, isActive: isRecording)
        }
        .disabled(permissionDenied || !permissionChecked)
        .onAppear { checkPermissions() }
        .onDisappear { stopRecording() }
    }

    private func checkPermissions() {
        guard !permissionChecked else { return }

        SFSpeechRecognizer.requestAuthorization { status in
            Task { @MainActor in
                if status != .authorized {
                    permissionDenied = true
                }
                permissionChecked = true
            }
        }

        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            Task { @MainActor in
                if !granted {
                    permissionDenied = true
                }
            }
        }
    }

    private func startRecording() {
        // Initialize lazily
        if speechRecognizer == nil {
            speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        }
        if audioEngine == nil {
            audioEngine = AVAudioEngine()
        }

        guard let recognizer = speechRecognizer, recognizer.isAvailable,
              let engine = audioEngine else { return }

        // Configure audio session
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            return
        }

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let request = recognitionRequest else { return }
        request.shouldReportPartialResults = true

        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)

        // Check format is valid
        guard format.sampleRate > 0 else { return }

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }

        engine.prepare()
        do {
            try engine.start()
        } catch {
            return
        }
        isRecording = true

        recognitionTask = recognizer.recognitionTask(with: request) { [self] result, error in
            Task { @MainActor in
                if let result = result {
                    text = result.bestTranscription.formattedString
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

        // Deactivate audio session
        try? AVAudioSession.sharedInstance().setActive(false)
    }
}
