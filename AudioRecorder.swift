//
//  AudioRecorder.swift
//  CreoleTranslator
//
//  Manages audio recording using AVFoundation
//

import Foundation
import AVFoundation

class AudioRecorder: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var lastRecordingURL: URL?
    @Published var lastError: String?

    private var audioRecorder: AVAudioRecorder?
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
                self.lastRecordingURL = audioFilename
                self.lastError = nil
            }

            return audioFilename
        } catch {
            DispatchQueue.main.async { self.lastError = "Could not start recording: \(error.localizedDescription)" }
            audioRecorder = nil
            return nil
        }
    }

    func stopRecording() -> URL? {
        guard let recorder = audioRecorder, recorder.isRecording else { return nil }
        recorder.stop()
        DispatchQueue.main.async { self.isRecording = false }
        let url = recorder.url
        audioRecorder = nil
        // Deactivate session to release resources (ignore errors)
        try? recordingSession.setActive(false)
        return url
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

        switch type {
        case .began:
            if audioRecorder?.isRecording == true {
                audioRecorder?.pause()
                DispatchQueue.main.async {
                    self.isRecording = false
                    self.lastError = "Recording paused due to interruption"
                }
            }
        case .ended:
            if let optionsValue = info[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if options.contains(.shouldResume) {
                    audioRecorder?.record()
                    DispatchQueue.main.async {
                        self.isRecording = true
                        self.lastError = nil
                    }
                }
            }
        @unknown default:
            break
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
