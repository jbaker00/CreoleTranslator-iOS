//
//  TextToSpeechManager.swift
//  CreoleTranslator
//
//  Text-to-speech manager using Groq playai-tts with AVSpeechSynthesizer fallback
//

import AVFoundation
import Foundation

class TextToSpeechManager: NSObject, ObservableObject {
    @Published var isSpeaking = false

    private let synthesizer = AVSpeechSynthesizer()
    private var audioPlayer: AVAudioPlayer?
    private var groqService: GroqService?

    // Initialise with an optional Groq API key.
    // When a valid key is provided, Groq playai-tts is used for supported languages;
    // AVSpeechSynthesizer is used as a fallback.
    init(apiKey: String? = nil) {
        super.init()
        synthesizer.delegate = self
        if let key = apiKey, !key.isEmpty {
            groqService = GroqService(apiKey: key)
        }
    }

    func speak(text: String, language: String = "en-US") {
        // Don't speak placeholder text
        guard !text.contains("Your translation") && !text.contains("Your transcription") && !text.isEmpty && text != "Waiting..." && text != "Processing..." else {
            return
        }

        stop()

        // Groq playai-tts currently supports English; fall back to native for other languages.
        let useGroq = groqService != nil && language.hasPrefix("en")

        if useGroq, let service = groqService {
            isSpeaking = true
            Task {
                do {
                    let audioData = try await service.synthesizeSpeech(text: text, voice: "Fritz-PlayAI")
                    await MainActor.run {
                        self.playAudioData(audioData)
                    }
                } catch {
                    // Fall back to AVSpeechSynthesizer on any Groq TTS error
                    await MainActor.run {
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
