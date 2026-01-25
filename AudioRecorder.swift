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
    
    private var audioRecorder: AVAudioRecorder?
    private var recordingSession: AVAudioSession?
    
    override init() {
        super.init()
        setupAudioSession()
    }
    
    private func setupAudioSession() {
        recordingSession = AVAudioSession.sharedInstance()
        
        do {
            try recordingSession?.setCategory(.playAndRecord, mode: .default)
            try recordingSession?.setActive(true)
        } catch {
            print("Failed to set up audio session: \(error.localizedDescription)")
        }
    }
    
    func requestPermission(completion: @escaping (Bool) -> Void) {
        recordingSession?.requestRecordPermission { allowed in
            DispatchQueue.main.async {
                completion(allowed)
            }
        }
    }
    
    func startRecording() -> URL? {
        let audioFilename = getDocumentsDirectory().appendingPathComponent("recording.m4a")
        
        let settings = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
            audioRecorder?.record()
            isRecording = true
            return audioFilename
        } catch {
            print("Could not start recording: \(error.localizedDescription)")
            return nil
        }
    }
    
    func stopRecording() -> URL? {
        guard let recorder = audioRecorder, recorder.isRecording else {
            return nil
        }
        
        recorder.stop()
        isRecording = false
        return recorder.url
    }
    
    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    func deleteRecording(at url: URL) {
        try? FileManager.default.removeItem(at: url)
    }
}
