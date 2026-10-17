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
    // Last HD clip, so replaying it costs neither a request nor an HD play.
    private var lastHDAudio: (key: String, data: Data, rate: Float)?
    private var requestID = UUID()

    private struct HDRequest {
        let provider: TTSProvider
        let voice: String
        let speed: Double
        let key: String
    }

    init(apiKey: String? = nil) {
        super.init()
        synthesizer.delegate = self
        groqService = GroqService()
        openAITTSService = OpenAITTSService()
    }

    /// `basicVoice` forces the on-device voice (chosen when out of HD plays).
    func speak(text: String, language: String = "en-US", basicVoice: Bool = false) {
        guard !text.contains("Your translation"),
              !text.contains("Your transcription"),
              !text.isEmpty,
              text != "Waiting...",
              text != "Processing..." else { return }

        stop()
        lastError = nil

        let isCreole = language.hasPrefix("ht")
        let speed = playbackSpeed(isCreole: isCreole)

        guard !basicVoice, let hd = hdRequest(text: text, language: language) else {
            speakNatively(text: text, language: language, speed: speed)
            return
        }

        // Replaying the clip just heard is free: no request, no HD play used.
        if let cached = lastHDAudio, cached.key == hd.key {
            isSpeaking = true
            playAudioData(cached.data, rate: cached.rate)
            return
        }

        // Callers that don't prompt first (History, Phrasebook) land here
        // when the user is out of HD plays.
        guard HDVoiceCredits.shared.playsLeft > 0 else {
            Analytics.logEvent("hd_voice_out_basic_fallback", parameters: ["language": language])
            speakNatively(text: text, language: language, speed: speed)
            return
        }

        let id = UUID()
        requestID = id
        isSpeaking = true
        Task {
            do {
                let (audioData, rate) = try await fetchAudio(hd, text: text, isCreole: isCreole)
                await MainActor.run {
                    // stop() or a newer speak() superseded this request.
                    guard self.requestID == id, self.isSpeaking else { return }
                    self.lastHDAudio = (hd.key, audioData, rate)
                    HDVoiceCredits.shared.consume()
                    self.playAudioData(audioData, rate: rate)
                }
            } catch {
                let msg = error.localizedDescription
                if hd.provider == .openai,
                   msg.localizedCaseInsensitiveContains("insufficient_quota") ||
                   msg.localizedCaseInsensitiveContains("exceeded your current quota") {
                    Analytics.logEvent("openai_tts_quota_exceeded", parameters: [
                        "voice": hd.voice, "text_length": text.count
                    ])
                }
                Analytics.logEvent("tts_fallback_to_computer", parameters: [
                    "provider": hd.provider.rawValue, "language": language, "reason": msg
                ])
                await MainActor.run {
                    guard self.requestID == id, self.isSpeaking else { return }
                    self.lastError = "\(hd.provider == .groq ? "Groq" : "OpenAI") TTS failed: \(msg)"
                    self.speakNatively(text: text, language: language, speed: speed)
                }
            }
        }
    }

    /// True when playing `text` now would use one of the user's HD plays.
    func usesHDPlay(text: String, language: String) -> Bool {
        guard let hd = hdRequest(text: text, language: language) else { return false }
        return lastHDAudio?.key != hd.key
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        audioPlayer?.stop()
        audioPlayer = nil
        isSpeaking = false
    }

    // MARK: - Private helpers

    private func playbackSpeed(isCreole: Bool) -> Double {
        let rawSpeed = UserDefaults.standard.double(forKey: isCreole ? "creolePlaybackSpeed" : "englishPlaybackSpeed")
        return rawSpeed == 0 ? (isCreole ? 0.7 : 1.0) : rawSpeed
    }

    /// The AI voice request for `text`, or nil when the system voice is selected.
    private func hdRequest(text: String, language: String) -> HDRequest? {
        let defaults = UserDefaults.standard
        let isCreole = language.hasPrefix("ht")
        let providerRaw = defaults.string(forKey: isCreole ? "creoleProvider" : "englishProvider")
        let provider = TTSProvider(rawValue: providerRaw ?? "") ?? (isCreole ? .openai : .groq)
        let voice: String
        switch provider {
        case .groq:   voice = defaults.string(forKey: "englishGroqVoice") ?? "diana"
        case .openai: voice = defaults.string(forKey: isCreole ? "creoleOpenAIVoice" : "englishOpenAIVoice") ?? "alloy"
        case .system: return nil
        }
        let speed = playbackSpeed(isCreole: isCreole)
        return HDRequest(provider: provider, voice: voice, speed: speed,
                         key: "\(provider.rawValue)|\(voice)|\(speed)|\(language)|\(text)")
    }

    private func fetchAudio(_ hd: HDRequest, text: String, isCreole: Bool) async throws -> (Data, Float) {
        switch hd.provider {
        case .groq:
            // Groq Orpheus — English only
            guard let service = groqService else { throw GroqError.invalidResponse }
            let data = try await service.synthesizeSpeech(text: text, voice: hd.voice, language: isCreole ? "ht" : "en")
            return (data, Float(hd.speed))
        default:
            guard let service = openAITTSService else { throw GroqError.invalidResponse }
            // OpenAI accepts speed directly; clamp to 0.25–4.0
            let apiSpeed = min(max(hd.speed, 0.25), 4.0)
            let data = try await service.synthesizeSpeech(text: text, voice: hd.voice, speed: apiSpeed, language: isCreole ? "ht" : "en")
            return (data, 1.0)
        }
    }

    private func playAudioData(_ data: Data, rate: Float = 1.0) {
        // Activate off the main thread (can block); see AVAudioSession.workQueue.
        AVAudioSession.workQueue.async {
            let session = AVAudioSession.sharedInstance()
            do {
                try session.setCategory(.playback, mode: .default)
                try session.setActive(true)
            } catch {
                DispatchQueue.main.async { self.isSpeaking = false }
                return
            }
            DispatchQueue.main.async {
                // stop() may have been tapped while the session was activating.
                guard self.isSpeaking else { return }
                do {
                    self.audioPlayer = try AVAudioPlayer(data: data)
                    self.audioPlayer?.delegate = self
                    self.audioPlayer?.enableRate = true
                    self.audioPlayer?.rate = rate
                    self.audioPlayer?.prepareToPlay()
                    self.audioPlayer?.play()
                } catch {
                    self.isSpeaking = false
                }
            }
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
