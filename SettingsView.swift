//
//  SettingsView.swift
//  CreoleTranslator
//
//  Per-language voice provider, voice selection, playback speed, and test buttons.
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject var voiceSettings: VoiceSettings
    @ObservedObject var ttsManager: TextToSpeechManager
    @Environment(\.dismiss) private var dismiss

    init(voiceSettings: VoiceSettings, ttsManager: TextToSpeechManager) {
        self.voiceSettings = voiceSettings
        self.ttsManager = ttsManager
    }

    var body: some View {
        NavigationView {
            Form {
                languageSection(isCreole: false)
                languageSection(isCreole: true)
                testSection
            }
            .navigationTitle("Voice Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - Per-language section

    @ViewBuilder
    private func languageSection(isCreole: Bool) -> some View {
        let flag      = isCreole ? "🇭🇹" : "🇺🇸"
        let langName  = isCreole ? "Haitian Creole" : "English"
        let providers = isCreole ? VoiceSettings.creoleProviders : VoiceSettings.englishProviders
        let provider  = isCreole ? voiceSettings.creoleProvider  : voiceSettings.englishProvider
        let speed     = isCreole ? voiceSettings.creolePlaybackSpeed : voiceSettings.englishPlaybackSpeed

        // Provider picker
        Section {
            ForEach(providers, id: \.rawValue) { p in
                Button {
                    if isCreole { voiceSettings.creoleProvider  = p }
                    else        { voiceSettings.englishProvider = p }
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(voiceSettings.displayName(for: p))
                                .font(.body)
                                .foregroundColor(.primary)
                            Text(voiceSettings.description(for: p))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: provider == p ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(provider == p ? .accentColor : Color(UIColor.tertiaryLabel))
                    }
                }
                .contentShape(Rectangle())
            }
        } header: {
            Label("\(flag) \(langName) — Voice Provider", systemImage: "speaker.wave.2")
        }

        // Voice list (hidden for System — iOS picks the voice automatically)
        if provider != .system {
            let voices     = provider == .groq ? VoiceSettings.groqVoices : VoiceSettings.openAIVoices
            let selectedId = selectedVoiceId(provider: provider, isCreole: isCreole)

            Section {
                ForEach(voices) { voice in
                    Button {
                        setVoice(voice.id, provider: provider, isCreole: isCreole)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(voice.name)
                                    .font(.body)
                                    .foregroundColor(.primary)
                                Text(voice.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            if voice.id == selectedId {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.accentColor)
                            }
                        }
                    }
                    .contentShape(Rectangle())
                }
            } header: {
                Text("Choose \(langName) Voice")
            } footer: {
                if provider == .groq {
                    Text("Groq Orpheus has a 200 character limit per utterance.")
                        .font(.caption)
                }
            }
        }

        // Speed slider
        Section {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "tortoise.fill").foregroundColor(.secondary)
                    if isCreole {
                        Slider(value: $voiceSettings.creolePlaybackSpeed, in: 0.5...1.5, step: 0.05)
                    } else {
                        Slider(value: $voiceSettings.englishPlaybackSpeed, in: 0.5...1.5, step: 0.05)
                    }
                    Image(systemName: "hare.fill").foregroundColor(.secondary)
                }
                Text(speedLabel(speed))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(.vertical, 4)

            if speed != (isCreole ? 0.7 : 1.0) {
                Button("Reset to Default") {
                    if isCreole { voiceSettings.creolePlaybackSpeed  = 0.7 }
                    else        { voiceSettings.englishPlaybackSpeed = 1.0 }
                }
                .font(.subheadline)
                .foregroundColor(.accentColor)
            }
        } header: {
            Text("\(langName) Playback Speed")
        } footer: {
            if isCreole {
                Text("Default is 0.70× — Creole voices tend to speak fast.")
                    .font(.caption)
            }
        }
    }

    // MARK: - Test section

    private var testSection: some View {
        Section {
            testButton(
                label: "Test Haitian Creole Voice",
                sample: "Bonjou, kijan ou rele?",
                language: "ht-HT"
            )
            testButton(
                label: "Test English Voice",
                sample: "Hello, how are you doing today?",
                language: "en-US"
            )

            if ttsManager.isSpeaking {
                Button { ttsManager.stop() } label: {
                    HStack {
                        Spacer()
                        Image(systemName: "stop.circle.fill").font(.title2)
                        Text("Stop").fontWeight(.semibold)
                        Spacer()
                    }
                    .foregroundColor(.red)
                    .padding(.vertical, 4)
                }
            }

            if let error = ttsManager.lastError {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.orange)
                    Text(error).font(.caption).foregroundColor(.orange)
                }
            }
        } header: {
            Label("Test Voice", systemImage: "ear")
        } footer: {
            Text("Tap to preview the selected voice and speed for each language.")
                .font(.caption)
        }
    }

    private func testButton(label: String, sample: String, language: String) -> some View {
        Button {
            if ttsManager.isSpeaking { ttsManager.stop() }
            else { ttsManager.speak(text: sample, language: language) }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(label).font(.body).foregroundColor(.primary)
                    Text("\"\(sample)\"").font(.caption).foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: ttsManager.isSpeaking ? "speaker.wave.3.fill" : "play.circle.fill")
                    .font(.title2)
                    .foregroundColor(.accentColor)
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Helpers

    private func selectedVoiceId(provider: TTSProvider, isCreole: Bool) -> String {
        switch provider {
        case .groq:   return voiceSettings.englishGroqVoice
        case .openai: return isCreole ? voiceSettings.creoleOpenAIVoice : voiceSettings.englishOpenAIVoice
        case .system: return ""
        }
    }

    private func setVoice(_ id: String, provider: TTSProvider, isCreole: Bool) {
        switch provider {
        case .groq:   voiceSettings.englishGroqVoice   = id
        case .openai:
            if isCreole { voiceSettings.creoleOpenAIVoice  = id }
            else        { voiceSettings.englishOpenAIVoice = id }
        case .system: break
        }
    }

    private func speedLabel(_ s: Double) -> String {
        switch s {
        case ..<0.65: return "Very Slow (\(String(format: "%.2f", s))×)"
        case ..<0.85: return "Slow (\(String(format: "%.2f", s))×)"
        case ..<1.1:  return "Normal (\(String(format: "%.2f", s))×)"
        case ..<1.3:  return "Fast (\(String(format: "%.2f", s))×)"
        default:      return "Very Fast (\(String(format: "%.2f", s))×)"
        }
    }
}

#Preview {
    SettingsView(
        voiceSettings: VoiceSettings(),
        ttsManager: TextToSpeechManager()
    )
}
