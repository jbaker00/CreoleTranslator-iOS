//
//  TextToSpeechManager.swift
//  CreoleTranslator
//
//  Text-to-speech manager using Groq playai-tts (English) and OpenAI TTS (Haitian Creole),
//  with AVSpeechSynthesizer as a final fallback.
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

    // Initialise with optional API keys.
    // Groq playai-tts is used for English; OpenAI TTS for Haitian Creole;
    // AVSpeechSynthesizer is used as a fallback when no matching service key is available.
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
        // Don't speak placeholder text
        guard !text.contains("Your translation") && !text.contains("Your transcription") && !text.isEmpty && text != "Waiting..." && text != "Processing..." else {
            return
        }

        stop()

        // Read voice preferences from UserDefaults (set via SettingsView / VoiceSettings)
        let groqVoice = UserDefaults.standard.string(forKey: "groqVoice") ?? "diana"
        let openAIVoice = UserDefaults.standard.string(forKey: "openAIVoice") ?? "alloy"
        let playbackSpeed = UserDefaults.standard.double(forKey: "ttsPlaybackSpeed")
        let speed = playbackSpeed == 0 ? 1.0 : playbackSpeed

        let isComputerVoice = { (voice: String) in voice == VoiceSettings.computerVoiceID }

        if language.hasPrefix("en"), let service = groqService, !isComputerVoice(groqVoice) {
            // Groq Orpheus TTS for English — speed applied via AVAudioPlayer.rate after decode
            isSpeaking = true
            Task {
                do {
                    let audioData = try await service.synthesizeSpeech(text: text, voice: groqVoice)
                    await MainActor.run {
                        self.playAudioData(audioData, rate: Float(speed))
                    }
                } catch {
                    let errorDesc = error.localizedDescription
                    Analytics.logEvent("tts_fallback_to_computer", parameters: [
                        "provider": "groq",
                        "language": language,
                        "reason": errorDesc
                    ])
                    print("[TTS] Groq TTS failed, falling back to native: \(error)")
                    await MainActor.run {
                        self.lastError = "Groq TTS failed: \(errorDesc)"
                        self.speakNatively(text: text, language: language, speed: speed)
                    }
                }
            }
        } else if language.hasPrefix("ht"), let service = openAITTSService, !isComputerVoice(openAIVoice) {
            // OpenAI TTS for Haitian Creole — speed sent directly in the API request
            isSpeaking = true
            Task {
                do {
                    let audioData = try await service.synthesizeSpeech(text: text, voice: openAIVoice, speed: speed)
                    await MainActor.run {
                        self.playAudioData(audioData, rate: 1.0) // speed already baked in by API
                    }
                } catch {
                    let errorDesc = error.localizedDescription
                    // Detect and log OpenAI quota exhaustion specifically
                    if errorDesc.localizedCaseInsensitiveContains("insufficient_quota") ||
                       errorDesc.localizedCaseInsensitiveContains("exceeded your current quota") {
                        Analytics.logEvent("openai_tts_quota_exceeded", parameters: [
                            "voice": openAIVoice,
                            "text_length": text.count
                        ])
                        print("[TTS] OpenAI quota exceeded — logged to Firebase Analytics")
                    }
                    Analytics.logEvent("tts_fallback_to_computer", parameters: [
                        "provider": "openai",
                        "language": language,
                        "reason": errorDesc
                    ])
                    print("[TTS] OpenAI TTS failed, falling back to native: \(error)")
                    await MainActor.run {
                        self.lastError = "OpenAI TTS failed: \(errorDesc)"
                        self.speakNatively(text: text, language: language, speed: speed)
                    }
                }
            }
        } else {
            // Computer voice selected by user, or no API service available
            speakNatively(text: text, language: language, speed: speed)
        }
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        audioPlayer?.stop()
        audioPlayer = nil
        isSpeaking = false
    }

    private func playAudioData(_ data: Data, rate: Float = 1.0) {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            audioPlayer = try AVAudioPlayer(data: data)
            audioPlayer?.delegate = self
            // enableRate must be set before prepareToPlay for rate changes to take effect
            audioPlayer?.enableRate = true
            audioPlayer?.rate = rate
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
        } catch {
            isSpeaking = false
        }
    }

    private func speakNatively(text: String, language: String, speed: Double = 1.0) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: language)
        // AVSpeechUtterance.rate range is 0.0–1.0; clamp our 0.5–1.5 UI range accordingly
        utterance.rate = Float(min(max(speed * 0.5, AVSpeechUtteranceMinimumSpeechRate), AVSpeechUtteranceMaximumSpeechRate))
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        isSpeaking = true
        synthesizer.speak(utterance)
    }
}

extension TextToSpeechManager: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isSpeaking = false
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isSpeaking = false
        }
    }
}

extension TextToSpeechManager: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async {
            self.isSpeaking = false
            self.audioPlayer = nil
        }
    }

    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        DispatchQueue.main.async {
            self.isSpeaking = false
            self.audioPlayer = nil
        }
    }
}
