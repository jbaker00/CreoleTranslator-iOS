//
//  TextToSpeechManager.swift
//  CreoleTranslator
//
//  Routes TTS to Groq Orpheus, OpenAI, or AVSpeechSynthesizer based on the
//  per-language provider selected in VoiceSettings.
//

import AVFoundation
import FirebaseAnalytics
import Foundation

class TextToSpeechManager: NSObject, ObservableObject {
    @Published var isSpeaking = false
    @Published var lastError: String?

    private let synthesizer = AVSpeechSynthesizer()
    private var audioPlayer: AVAudioPlayer?
    private var groqService: GroqService?
    private var openAITTSService: OpenAITTSService?

    init(apiKey: String? = nil, openAIApiKey: String? = nil) {
        super.init()
        synthesizer.delegate = self
        if let key = apiKey, !key.isEmpty {
            groqService = GroqService(apiKey: key)
        }
        if let key = openAIApiKey, !key.isEmpty {
            openAITTSService = OpenAITTSService(apiKey: key)
        }
    }

    func speak(text: String, language: String = "en-US") {
        guard !text.contains("Your translation"),
              !text.contains("Your transcription"),
              !text.isEmpty,
              text != "Waiting...",
              text != "Processing..." else { return }

        stop()
        lastError = nil

        let defaults = UserDefaults.standard
        let isCreole = language.hasPrefix("ht")

        // Read per-language provider, voice, and speed
        let providerRaw = defaults.string(forKey: isCreole ? "creoleProvider" : "englishProvider")
        let provider = TTSProvider(rawValue: providerRaw ?? "") ?? (isCreole ? .openai : .groq)

        let rawSpeed = defaults.double(forKey: isCreole ? "creolePlaybackSpeed" : "englishPlaybackSpeed")
        let speed = rawSpeed == 0 ? (isCreole ? 0.7 : 1.0) : rawSpeed

        switch provider {
        case .groq:
            // Groq Orpheus — English only
            guard let service = groqService else {
                speakNatively(text: text, language: language, speed: speed)
                return
            }
            let voice = defaults.string(forKey: "englishGroqVoice") ?? "diana"
            isSpeaking = true
            Task {
                do {
                    let audioData = try await service.synthesizeSpeech(text: text, voice: voice)
                    await MainActor.run { self.playAudioData(audioData, rate: Float(speed)) }
                } catch {
                    let msg = error.localizedDescription
                    Analytics.logEvent("tts_fallback_to_computer", parameters: [
                        "provider": "groq", "language": language, "reason": msg
                    ])
                    await MainActor.run {
                        self.lastError = "Groq TTS failed: \(msg)"
                        self.speakNatively(text: text, language: language, speed: speed)
                    }
                }
            }

        case .openai:
            guard let service = openAITTSService else {
                speakNatively(text: text, language: language, speed: speed)
                return
            }
            let voiceKey = isCreole ? "creoleOpenAIVoice" : "englishOpenAIVoice"
            let voice = defaults.string(forKey: voiceKey) ?? "alloy"
            isSpeaking = true
            Task {
                do {
                    // OpenAI accepts speed directly; clamp to 0.25–4.0
                    let apiSpeed = min(max(speed, 0.25), 4.0)
                    let audioData = try await service.synthesizeSpeech(text: text, voice: voice, speed: apiSpeed)
                    await MainActor.run { self.playAudioData(audioData, rate: 1.0) }
                } catch {
                    let msg = error.localizedDescription
                    if msg.localizedCaseInsensitiveContains("insufficient_quota") ||
                       msg.localizedCaseInsensitiveContains("exceeded your current quota") {
                        Analytics.logEvent("openai_tts_quota_exceeded", parameters: [
                            "voice": voice, "text_length": text.count
                        ])
                    }
                    Analytics.logEvent("tts_fallback_to_computer", parameters: [
                        "provider": "openai", "language": language, "reason": msg
                    ])
                    await MainActor.run {
                        self.lastError = "OpenAI TTS failed: \(msg)"
                        self.speakNatively(text: text, language: language, speed: speed)
                    }
                }
            }

        case .system:
            speakNatively(text: text, language: language, speed: speed)
        }
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        audioPlayer?.stop()
        audioPlayer = nil
        isSpeaking = false
    }

    // MARK: - Private helpers

    private func playAudioData(_ data: Data, rate: Float = 1.0) {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            audioPlayer = try AVAudioPlayer(data: data)
            audioPlayer?.delegate = self
            audioPlayer?.enableRate = true
            audioPlayer?.rate = rate
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
        } catch {
            isSpeaking = false
        }
    }

    private func speakNatively(text: String, language: String, speed: Double) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: language)
        utterance.rate = min(
            max(Float(speed) * 0.5, AVSpeechUtteranceMinimumSpeechRate),
            AVSpeechUtteranceMaximumSpeechRate
        )
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        isSpeaking = true
        synthesizer.speak(utterance)
    }
}

extension TextToSpeechManager: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { self.isSpeaking = false }
    }
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { self.isSpeaking = false }
    }
}

extension TextToSpeechManager: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async { self.isSpeaking = false; self.audioPlayer = nil }
    }
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        DispatchQueue.main.async { self.isSpeaking = false; self.audioPlayer = nil }
    }
}
