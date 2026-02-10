import SwiftUI

struct VoiceInputButton: View {
    @Binding var text: String
    @State private var engine = SpeechRecognitionEngine()
    @State private var errorMessage: String?

    var body: some View {
        Button {
            if engine.permissionDenied {
                SpeechRecognitionEngine.openAppSettings()
            } else {
                engine.isRecording ? engine.stopRecording() : startRecording()
            }
        } label: {
            Image(systemName: engine.permissionDenied ? "mic.slash.circle.fill" : (engine.isRecording ? "stop.circle.fill" : "mic.circle.fill"))
                .font(.title)
                .foregroundStyle(engine.permissionDenied ? .secondary : (engine.isRecording ? .red : Color.themePrimary))
                .symbolEffect(.pulse, isActive: engine.isRecording)
        }
        .disabled(!engine.permissionChecked && !engine.permissionDenied)
        .onAppear { engine.checkPermissions() }
        .onDisappear { engine.stopRecording() }
        .help(engine.permissionDenied ? "Microphone access required. Tap to open Settings." : "")
        .onChange(of: engine.transcribedText) { _, newValue in
            text = newValue
        }
        .alert("Voice Input Error", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func startRecording() {
        errorMessage = nil
        engine.startRecording()
        if !engine.isRecording {
            errorMessage = "Speech recognition is not available"
        }
    }
}
