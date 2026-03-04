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
    // Voice used for English TTS (Groq). Defaults to Diana.
    @AppStorage("groqVoice") var groqVoice: String = "diana"

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
        Voice(id: "echo",     name: "Echo",           description: "Warm & clear"),
        Voice(id: "fable",    name: "Fable",          description: "Expressive & dynamic"),
        Voice(id: "onyx",     name: "Onyx",           description: "Deep & authoritative"),
        Voice(id: "nova",     name: "Nova",           description: "Friendly & upbeat"),
        Voice(id: "shimmer",  name: "Shimmer",        description: "Soft & gentle"),
        Voice(id: "computer", name: "Computer Voice", description: "Built-in iOS synthesizer"),
    ]

    // Groq Orpheus English voices (Diana is the only confirmed working voice)
    static let groqVoices: [Voice] = [
        Voice(id: "diana",    name: "Diana",          description: "Clear & professional"),
        Voice(id: "computer", name: "Computer Voice", description: "Built-in iOS synthesizer"),
    ]
}
