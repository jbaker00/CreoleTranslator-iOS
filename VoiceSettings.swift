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

    // --- Translation ---
    // When on, clearly-English text sent while in Creole→English (or vice
    // versa) is translated in the detected direction, with an Undo chip.
    @AppStorage("autoDetectLanguage") var autoDetectLanguage: Bool = true

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

    func usesHDVoice(isCreole: Bool) -> Bool {
        (isCreole ? creoleProvider : englishProvider) != .system
    }

    func description(for provider: TTSProvider, isCreole: Bool = false) -> String {
        switch provider {
        case .groq:   return "High-quality AI voices (6 options) — English only"
        case .openai: return "Natural multilingual voices (6 options)"
        case .system: return "Built-in iOS voice — works offline"
        }
    }
}

// MARK: - HD voice plays (rewarded ad)

/// AI ("HD") voice playback — Groq or OpenAI, both billed per request — is
/// metered per device: a few free plays a day, more for each rewarded ad.
/// Free plays reset at local midnight and are used first; ad plays carry
/// over. The count lives on the device, so the api-proxy's per-device and
/// global OpenAI TTS caps stay the real spend ceiling.
final class HDVoiceCredits: ObservableObject {
    static let shared = HDVoiceCredits()

    static let freePlaysPerDay = 5
    static let playsPerAd = 10
    /// Grants allowed per day when no video can be shown (no-fill, airplane
    /// mode, ad blocker). Keeps a genuine no-fill from punishing the user
    /// without making "turn off Wi-Fi, tap Watch Video" an unlimited bypass.
    static let noAdGrantsPerDay = 1

    private let defaults = UserDefaults.standard
    private let dayKey = "hdFreePlaysDay"
    private let usedKey = "hdFreePlaysUsed"
    private let bonusKey = "hdBonusPlays"
    private let noAdDayKey = "hdNoAdGrantDay"
    private let noAdUsedKey = "hdNoAdGrantsUsed"
    private let noAdBlockedKey = "hdNoAdGrantsBlocked"

    private static var today: String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        return "\(c.year ?? 0)-\(c.month ?? 0)-\(c.day ?? 0)"
    }

    private var freeUsedToday: Int {
        defaults.string(forKey: dayKey) == Self.today ? defaults.integer(forKey: usedKey) : 0
    }

    var freePlaysLeft: Int { max(0, Self.freePlaysPerDay - freeUsedToday) }
    var bonusPlaysLeft: Int { defaults.integer(forKey: bonusKey) }
    var playsLeft: Int { freePlaysLeft + bonusPlaysLeft }

    private var noAdGrantsToday: Int {
        defaults.string(forKey: noAdDayKey) == Self.today ? defaults.integer(forKey: noAdUsedKey) : 0
    }

    var canGrantWithoutAd: Bool { noAdGrantsToday < Self.noAdGrantsPerDay }

    func recordGrantWithoutAd() {
        let used = noAdGrantsToday
        defaults.set(Self.today, forKey: noAdDayKey)
        defaults.set(used + 1, forKey: noAdUsedKey)
    }

    /// Lifetime count of refused no-video grants, for analytics.
    func recordBlockedGrant() -> Int {
        let total = defaults.integer(forKey: noAdBlockedKey) + 1
        defaults.set(total, forKey: noAdBlockedKey)
        return total
    }

    /// Call on the main thread after an HD clip actually arrives.
    func consume() {
        if freePlaysLeft > 0 {
            let used = freeUsedToday
            defaults.set(Self.today, forKey: dayKey)
            defaults.set(used + 1, forKey: usedKey)
        } else if bonusPlaysLeft > 0 {
            defaults.set(bonusPlaysLeft - 1, forKey: bonusKey)
        }
        objectWillChange.send()
    }

    func grantAdReward() {
        defaults.set(bonusPlaysLeft + Self.playsPerAd, forKey: bonusKey)
        objectWillChange.send()
    }

    /// Re-renders observers so a new day's free plays show up.
    func refresh() {
        objectWillChange.send()
    }
}

// MARK: - AppStorage support for TTSProvider

extension TTSProvider: RawRepresentable {}
