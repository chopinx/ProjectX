import Speech
import AVFoundation
import Observation
import UIKit

/// Shared speech recognition engine used by both VoiceInputButton and HoldToSpeakButton.
/// Encapsulates permission checking, audio session management, and speech-to-text transcription.
@Observable
final class SpeechRecognitionEngine {
    var isRecording = false
    var permissionDenied = false
    var permissionChecked = false
    var transcribedText = ""

    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioEngine: AVAudioEngine?
    private var recordingStartTime: Date?

    func checkPermissions() {
        guard !permissionChecked else { return }

        Task {
            let speechStatus = await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { status in
                    continuation.resume(returning: status)
                }
            }

            let audioGranted = await AVAudioApplication.requestRecordPermission()

            if speechStatus != .authorized || !audioGranted {
                permissionDenied = true
            }
            permissionChecked = true
        }
    }

    func startRecording() {
        transcribedText = ""
        recordingStartTime = .now

        if speechRecognizer == nil {
            speechRecognizer = SFSpeechRecognizer(locale: .current)
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

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let result = result {
                    self.transcribedText = result.bestTranscription.formattedString
                }
                if error != nil || result?.isFinal == true {
                    self.stopRecording()
                }
            }
        }
    }

    func stopRecording() {
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

    /// Stops recording with a minimum duration guarantee, then calls the completion handler with the transcribed text.
    func stopRecordingWithMinimumDuration(_ minimum: TimeInterval = 0.5, completion: @escaping (String?) -> Void) {
        let elapsed = recordingStartTime.map { Date.now.timeIntervalSince($0) } ?? 0
        let remaining = max(0, minimum - elapsed)

        let finish = { [weak self] in
            guard let self else { return }
            self.stopRecording()
            let text = self.transcribedText.trimmingCharacters(in: .whitespacesAndNewlines)
            completion(text.isEmpty ? nil : text)
        }

        if remaining > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + remaining, execute: finish)
        } else {
            finish()
        }
    }

    static func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
