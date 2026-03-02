//
//  TextToSpeechManager.swift
//  CreoleTranslator
//
//  Text-to-speech manager using Groq playai-tts (English) and OpenAI TTS (Haitian Creole),
//  with AVSpeechSynthesizer as a final fallback.
//

import AVFoundation
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

        if language.hasPrefix("en"), let service = groqService {
            // Groq playai-tts for English
            isSpeaking = true
            Task {
                do {
                    let audioData = try await service.synthesizeSpeech(text: text, voice: "diana")
                    await MainActor.run {
                        self.playAudioData(audioData)
                    }
                } catch {
                    print("[TTS] Groq TTS failed, falling back to native: \(error)")
                    await MainActor.run {
                        self.lastError = "Groq TTS failed: \(error.localizedDescription)"
                        self.speakNatively(text: text, language: language)
                    }
                }
            }
        } else if language.hasPrefix("ht"), let service = openAITTSService {
            // OpenAI TTS for Haitian Creole (ht, ht-HT)
            isSpeaking = true
            Task {
                do {
                    let audioData = try await service.synthesizeSpeech(text: text, voice: "alloy")
                    await MainActor.run {
                        self.playAudioData(audioData)
                    }
                } catch {
                    print("[TTS] OpenAI TTS failed, falling back to native: \(error)")
                    await MainActor.run {
                        self.lastError = "OpenAI TTS failed: \(error.localizedDescription)"
                        self.speakNatively(text: text, language: language)
                    }
                }
            }
        } else {
            speakNatively(text: text, language: language)
        }
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        audioPlayer?.stop()
        audioPlayer = nil
        isSpeaking = false
    }

    private func playAudioData(_ data: Data) {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            audioPlayer = try AVAudioPlayer(data: data)
            audioPlayer?.delegate = self
            audioPlayer?.play()
        } catch {
            isSpeaking = false
        }
    }

    private func speakNatively(text: String, language: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: language)
        utterance.rate = 0.5
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
