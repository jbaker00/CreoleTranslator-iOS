//
//  AudioRecorder.swift
//  CreoleTranslator
//
//  Manages audio recording using AVFoundation
//

import Foundation
import AVFoundation

class AudioRecorder: NSObject, ObservableObject {
    // Accuracy falls off with clip length: across 3,632 voice samples, translations
    // scored confidence ≤3 for 21% of <10s clips, 43% at 10–20s, 57%+ past 20s.
    // So recordings stop at maxDuration, and the bar warns after warnAfter.
    static let maxDuration: TimeInterval = 30
    static let warnAfter: TimeInterval = 20
    // Shorter clips are almost always accidental taps; don't send them.
    static let minDuration: TimeInterval = 0.6

    @Published var isRecording = false
    @Published var elapsed: TimeInterval = 0
    @Published var lastRecordingURL: URL?
    @Published var lastError: String?

    /// Called on the main queue when a recording hits maxDuration and stops itself.
    var onAutoStop: ((URL) -> Void)?

    private var audioRecorder: AVAudioRecorder?
    private var progressTimer: Timer?
    private var recordingSession: AVAudioSession

    override init() {
        self.recordingSession = AVAudioSession.sharedInstance()
        super.init()
        // Do not activate the session here. Activate it when starting a recording.
        NotificationCenter.default.addObserver(self, selector: #selector(handleInterruption(_:)), name: AVAudioSession.interruptionNotification, object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func requestPermission(completion: @escaping (Bool) -> Void) {
        recordingSession.requestRecordPermission { allowed in
            DispatchQueue.main.async {
                completion(allowed)
            }
        }
    }

    // Keep the same synchronous signature for compatibility with existing callers.
    // This method will request permission if needed (synchronously waiting briefly) and then start recording.
    func startRecording() -> URL? {
        // Check permission
        switch recordingSession.recordPermission {
        case .granted:
            break // continue
        case .denied:
            DispatchQueue.main.async { self.lastError = "Microphone permission denied" }
            return nil
        case .undetermined:
            // Request permission and wait briefly (avoid indefinite blocking)
            let sem = DispatchSemaphore(value: 0)
            var allowed = false
            recordingSession.requestRecordPermission { granted in
                allowed = granted
                sem.signal()
            }
            // Wait up to 5 seconds for user action (UI will show prompt)
            let _ = sem.wait(timeout: .now() + 5)
            if !allowed {
                DispatchQueue.main.async { self.lastError = "Microphone permission denied or timed out" }
                return nil
            }
        @unknown default:
            DispatchQueue.main.async { self.lastError = "Unknown microphone permission state" }
            return nil
        }

        // Configure and activate session
        do {
            try recordingSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetoothA2DP])
            try recordingSession.setActive(true)
        } catch {
            DispatchQueue.main.async { self.lastError = "Failed to activate audio session: \(error.localizedDescription)" }
            return nil
        }

        // Unique filename: ISO8601 timestamp + UUID
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let timestamp = formatter.string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let filename = "recording_\(timestamp)_\(UUID().uuidString).m4a"
        let audioFilename = getDocumentsDirectory().appendingPathComponent(filename)

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.prepareToRecord()
            if audioRecorder?.record() == false {
                DispatchQueue.main.async { self.lastError = "Failed to start recording." }
                audioRecorder = nil
                return nil
            }

            DispatchQueue.main.async {
                self.isRecording = true
                self.elapsed = 0
                self.lastRecordingURL = audioFilename
                self.lastError = nil
                self.startProgressTimer()
            }

            return audioFilename
        } catch {
            DispatchQueue.main.async { self.lastError = "Could not start recording: \(error.localizedDescription)" }
            audioRecorder = nil
            return nil
        }
    }

    /// Stops the recording and returns the clip, or nil if nothing was recording
    /// or the clip was shorter than minDuration (that file is deleted).
    func stopRecording() -> URL? {
        guard let recorder = audioRecorder, recorder.isRecording else { return nil }
        let duration = recorder.currentTime
        recorder.stop()
        stopProgressTimer()
        DispatchQueue.main.async { self.isRecording = false }
        let url = recorder.url
        audioRecorder = nil
        // Deactivate session to release resources (ignore errors)
        try? recordingSession.setActive(false)
        if duration < Self.minDuration {
            deleteRecording(at: url)
            return nil
        }
        return url
    }

    private func startProgressTimer() {
        stopProgressTimer()
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self, let recorder = self.audioRecorder, recorder.isRecording else { return }
            self.elapsed = min(recorder.currentTime, Self.maxDuration)
            if recorder.currentTime >= Self.maxDuration, let url = self.stopRecording() {
                self.onAutoStop?(url)
            }
        }
    }

    private func stopProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = nil
    }

    func deleteRecording(at url: URL) {
        do {
            try FileManager.default.removeItem(at: url)
            DispatchQueue.main.async {
                if self.lastRecordingURL == url { self.lastRecordingURL = nil }
            }
        } catch {
            DispatchQueue.main.async { self.lastError = "Failed to delete recording: \(error.localizedDescription)" }
        }
    }

    private func getDocumentsDirectory() -> URL {
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }

    // Handle interruptions (phone call, Siri, etc.)
    @objc private func handleInterruption(_ notification: Notification) {
        guard let info = notification.userInfo,
              let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }

        // A paused AVAudioRecorder can't be resumed reliably after a call or Siri,
        // and the UI would show "Start" over a half-finished clip. Discard it instead.
        guard type == .began else { return }
        DispatchQueue.main.async {
            guard let recorder = self.audioRecorder else { return }
            let url = recorder.url
            recorder.stop()
            self.stopProgressTimer()
            self.audioRecorder = nil
            try? self.recordingSession.setActive(false)
            self.deleteRecording(at: url)
            self.isRecording = false
            self.elapsed = 0
            self.lastError = "Recording stopped by an interruption. Please try again."
        }
    }

    enum RecorderError: Error {
        case permissionDenied
        case sessionActivationFailed(Error)
        case recorderInitFailed(Error)
        case notRecording
        case deleteFailed(Error)
    }
}

extension AudioRecorder: AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        DispatchQueue.main.async {
            self.isRecording = false
            if !flag {
                self.lastError = "Recording finished unsuccessfully"
            }
        }
    }
}
