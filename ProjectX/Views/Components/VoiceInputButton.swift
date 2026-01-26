import SwiftUI
import Speech
import AVFoundation

struct VoiceInputButton: View {
    @Binding var text: String
    @State private var isRecording = false
    @State private var speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    @State private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    @State private var recognitionTask: SFSpeechRecognitionTask?
    @State private var audioEngine = AVAudioEngine()
    @State private var permissionDenied = false

    var body: some View {
        Button {
            isRecording ? stopRecording() : startRecording()
        } label: {
            Image(systemName: isRecording ? "stop.circle.fill" : "mic.circle.fill")
                .font(.title)
                .foregroundStyle(isRecording ? .red : Color.themePrimary)
                .symbolEffect(.pulse, isActive: isRecording)
        }
        .disabled(permissionDenied)
        .onAppear { requestPermissions() }
    }

    private func requestPermissions() {
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async { permissionDenied = status != .authorized }
        }
        AVAudioApplication.requestRecordPermission { granted in
            DispatchQueue.main.async { if !granted { permissionDenied = true } }
        }
    }

    private func startRecording() {
        guard let recognizer = speechRecognizer, recognizer.isAvailable else { return }
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let request = recognitionRequest else { return }
        request.shouldReportPartialResults = true

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }

        audioEngine.prepare()
        try? audioEngine.start()
        isRecording = true

        recognitionTask = recognizer.recognitionTask(with: request) { result, error in
            if let result = result {
                text = result.bestTranscription.formattedString
            }
            if error != nil || result?.isFinal == true {
                stopRecording()
            }
        }
    }

    private func stopRecording() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
        isRecording = false
    }
}
