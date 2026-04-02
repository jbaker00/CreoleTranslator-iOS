//
//  VoiceSettings.swift
//  CreoleTranslator
//
//  Persisted voice preferences for TTS playback.
//  Stored via AppStorage (UserDefaults) so selections survive app restarts.
//

import SwiftUI

class VoiceSettings: ObservableObject {
    // Voice used for Haitian Creole TTS (OpenAI)
    @AppStorage("openAIVoice") var openAIVoice: String = "alloy"
    // Voice used for English TTS (Groq Orpheus)
    @AppStorage("groqVoice") var groqVoice: String = "diana"
    // Playback speed: 0.5 = half speed, 1.0 = normal, 1.5 = faster
    // Applies to all providers. System voice uses AVSpeechUtterance.rate (clamped to 0.1–1.0);
    // API providers apply it via AVAudioPlayer.rate or API speed param.
    @AppStorage("ttsPlaybackSpeed") var playbackSpeed: Double = 1.0

    struct Voice: Identifiable {
        let id: String
        let name: String
        let description: String
    }

    // Sentinel value meaning "use the built-in AVSpeechSynthesizer"
    static let computerVoiceID = "computer"

    // OpenAI tts-1 multilingual voices + computer fallback
    static let openAIVoices: [Voice] = [
        Voice(id: "alloy",    name: "Alloy",          description: "Neutral & balanced"),
        Voice(id: "echo",     name: "Echo",            description: "Warm & clear (male)"),
        Voice(id: "fable",    name: "Fable",           description: "Expressive, British accent"),
        Voice(id: "onyx",     name: "Onyx",            description: "Deep & authoritative (male)"),
        Voice(id: "nova",     name: "Nova",            description: "Friendly & upbeat (female)"),
        Voice(id: "shimmer",  name: "Shimmer",         description: "Soft & gentle (female)"),
        Voice(id: "computer", name: "Computer Voice",  description: "Built-in iOS synthesizer"),
    ]

    // All confirmed Groq Orpheus voices + computer fallback
    static let groqVoices: [Voice] = [
        Voice(id: "autumn",   name: "Autumn",          description: "Warm female voice"),
        Voice(id: "diana",    name: "Diana",           description: "Clear & professional (female)"),
        Voice(id: "hannah",   name: "Hannah",          description: "Bright female voice"),
        Voice(id: "austin",   name: "Austin",          description: "Casual male voice"),
        Voice(id: "daniel",   name: "Daniel",          description: "Smooth male voice"),
        Voice(id: "troy",     name: "Troy",            description: "Bold male voice"),
        Voice(id: "computer", name: "Computer Voice",  description: "Built-in iOS synthesizer"),
    ]
}
