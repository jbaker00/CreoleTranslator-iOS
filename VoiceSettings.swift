//
//  VoiceSettings.swift
//  CreoleTranslator
//
//  Persisted voice preferences for TTS playback.
//  Stored via AppStorage (UserDefaults) so selections survive app restarts.
//

import SwiftUI

// MARK: - Provider enum

enum TTSProvider: String {
    case groq   = "groq"
    case openai = "openai"
    case system = "system"
}

// MARK: - VoiceSettings

class VoiceSettings: ObservableObject {

    // --- English ---
    // Provider: Groq / OpenAI / System
    @AppStorage("englishProvider") var englishProvider: TTSProvider = .groq
    @AppStorage("englishGroqVoice")   var englishGroqVoice: String   = "diana"
    @AppStorage("englishOpenAIVoice") var englishOpenAIVoice: String = "alloy"
    // Speed: 0.5–1.5×, default normal
    @AppStorage("englishPlaybackSpeed") var englishPlaybackSpeed: Double = 1.0

    // --- Haitian Creole ---
    // Provider: OpenAI / System only (Groq Orpheus is English-only)
    @AppStorage("creoleProvider") var creoleProvider: TTSProvider = .openai
    @AppStorage("creoleOpenAIVoice") var creoleOpenAIVoice: String = "alloy"
    // Speed: default 0.7 — Creole voices tend to speak fast
    @AppStorage("creolePlaybackSpeed") var creolePlaybackSpeed: Double = 0.7

    // MARK: - Voice catalogues

    struct Voice: Identifiable {
        let id: String
        let name: String
        let description: String
    }

    // Groq Orpheus voices (English only)
    static let groqVoices: [Voice] = [
        Voice(id: "autumn", name: "Autumn", description: "Warm female voice"),
        Voice(id: "diana",  name: "Diana",  description: "Clear & professional (female)"),
        Voice(id: "hannah", name: "Hannah", description: "Bright female voice"),
        Voice(id: "austin", name: "Austin", description: "Casual male voice"),
        Voice(id: "daniel", name: "Daniel", description: "Smooth male voice"),
        Voice(id: "troy",   name: "Troy",   description: "Bold male voice"),
    ]

    // OpenAI tts-1 multilingual voices
    static let openAIVoices: [Voice] = [
        Voice(id: "alloy",   name: "Alloy",   description: "Neutral & balanced"),
        Voice(id: "echo",    name: "Echo",    description: "Warm & clear (male)"),
        Voice(id: "fable",   name: "Fable",   description: "Expressive, British accent"),
        Voice(id: "onyx",    name: "Onyx",    description: "Deep & authoritative (male)"),
        Voice(id: "nova",    name: "Nova",    description: "Friendly & upbeat (female)"),
        Voice(id: "shimmer", name: "Shimmer", description: "Soft & gentle (female)"),
    ]

    // MARK: - Helpers

    /// Providers valid for English
    static let englishProviders: [TTSProvider] = [.groq, .openai, .system]
    /// Providers valid for Creole (Groq Orpheus is English-only so excluded)
    static let creoleProviders:  [TTSProvider] = [.openai, .system]

    func displayName(for provider: TTSProvider) -> String {
        switch provider {
        case .groq:   return "Groq Orpheus"
        case .openai: return "OpenAI"
        case .system: return "System Voice"
        }
    }

    func description(for provider: TTSProvider, isCreole: Bool = false) -> String {
        switch provider {
        case .groq:   return "High-quality AI voices (6 options) — English only"
        case .openai: return "Natural multilingual voices (6 options)"
        case .system: return "Built-in iOS voice — works offline"
        }
    }
}

// MARK: - AppStorage support for TTSProvider

extension TTSProvider: RawRepresentable {}
