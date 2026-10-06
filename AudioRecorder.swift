//
//  AudioRecorder.swift
//  CreoleTranslator
//
//  Manages audio recording using AVFoundation
//

import Foundation
import AVFoundation

extension AVAudioSession {
    /// setActive/setCategory can block for a noticeable time, so never call them on the
    /// main thread. Recording and TTS share this serial queue so a deactivate queued by
    /// a finished recording can't land after playback has activated the session.
    /// (The async activate/deactivate API is iOS 27+; we support iOS 15.)
    static let workQueue = DispatchQueue(label: "com.jbaker.CreoleTranslator.audio-session", qos: .userInitiated)
}

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
    private var isStarting = false
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

    /// Activates the session and starts recording off the main thread, then calls
    /// `completion` on the main queue with the clip URL, or nil on failure (see lastError).
    /// Callers request mic permission first (ContentView does, in context).
    func startRecording(completion: @escaping (URL?) -> Void) {
        guard !isStarting, audioRecorder == nil else { return }
        isStarting = true
        let session = recordingSession
        AVAudioSession.workQueue.async {
            let result = Self.makeRecorder(session: session)
            DispatchQueue.main.async {
                self.isStarting = false
                switch result {
                case .success(let recorder):
                    recorder.delegate = self
                    self.audioRecorder = recorder
                    self.isRecording = true
                    self.elapsed = 0
                    self.lastRecordingURL = recorder.url
                    self.lastError = nil
                    self.startProgressTimer()
                    completion(recorder.url)
                case .failure(let error):
                    self.lastError = error.message
                    completion(nil)
                }
            }
        }
    }

    private struct StartError: Error { let message: String }

    /// Runs on AVAudioSession.workQueue.
    private static func makeRecorder(session: AVAudioSession) -> Result<AVAudioRecorder, StartError> {
        guard session.recordPermission == .granted else {
            return .failure(StartError(message: "Microphone permission denied"))
        }

        do {
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetoothA2DP])
            try session.setActive(true)
        } catch {
            return .failure(StartError(message: "Failed to activate audio session: \(error.localizedDescription)"))
        }

        // Unique filename: ISO8601 timestamp + UUID
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let timestamp = formatter.string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let filename = "recording_\(timestamp)_\(UUID().uuidString).m4a"
        let audioFilename = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(filename)

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            let recorder = try AVAudioRecorder(url: audioFilename, settings: settings)
            recorder.isMeteringEnabled = true
            recorder.prepareToRecord()
            guard recorder.record() else {
                try? session.setActive(false)
                return .failure(StartError(message: "Failed to start recording."))
            }
            return .success(recorder)
        } catch {
            try? session.setActive(false)
            return .failure(StartError(message: "Could not start recording: \(error.localizedDescription)"))
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
        deactivateSession()
        if duration < Self.minDuration {
            deleteRecording(at: url)
            return nil
        }
        return url
    }

    /// Release the session so other apps' audio can resume (errors ignored).
    private func deactivateSession() {
        let session = recordingSession
        AVAudioSession.workQueue.async {
            try? session.setActive(false, options: .notifyOthersOnDeactivation)
        }
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
            self.deactivateSession()
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
