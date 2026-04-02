//
//  SettingsView.swift
//  CreoleTranslator
//
//  Options screen for selecting TTS voices per language and playback speed.
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
                // MARK: - Haitian Creole Voice (OpenAI)
                Section {
                    ForEach(VoiceSettings.openAIVoices) { voice in
                        VoiceRow(
                            voice: voice,
                            isSelected: voiceSettings.openAIVoice == voice.id
                        ) {
                            voiceSettings.openAIVoice = voice.id
                        }
                    }
                } header: {
                    Label("Haitian Creole Voice (OpenAI TTS)", systemImage: "waveform")
                } footer: {
                    Text("Used when playing Haitian Creole text.")
                        .font(.caption)
                }

                // MARK: - English Voice (Groq)
                Section {
                    ForEach(VoiceSettings.groqVoices) { voice in
                        VoiceRow(
                            voice: voice,
                            isSelected: voiceSettings.groqVoice == voice.id
                        ) {
                            voiceSettings.groqVoice = voice.id
                        }
                    }
                } header: {
                    Label("English Voice (Groq Orpheus TTS)", systemImage: "waveform")
                } footer: {
                    Text("Used when playing English text. Groq Orpheus has a 200 character limit per utterance.")
                        .font(.caption)
                }

                // MARK: - Playback Speed
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Image(systemName: "tortoise.fill")
                                .foregroundColor(.secondary)
                            Slider(value: $voiceSettings.playbackSpeed, in: 0.5...1.5, step: 0.05)
                                .accentColor(.accentColor)
                            Image(systemName: "hare.fill")
                                .foregroundColor(.secondary)
                        }
                        HStack {
                            Spacer()
                            Text(speedLabel)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                    }
                    .padding(.vertical, 4)

                    // Reset to normal speed
                    if voiceSettings.playbackSpeed != 1.0 {
                        Button("Reset to Normal Speed") {
                            voiceSettings.playbackSpeed = 1.0
                        }
                        .font(.subheadline)
                        .foregroundColor(.accentColor)
                    }
                } header: {
                    Label("Playback Speed", systemImage: "speedometer")
                } footer: {
                    Text("Reduce speed if voices sound too fast, especially for Creole playback.")
                        .font(.caption)
                }

                // MARK: - Test Voice
                Section {
                    // Creole test
                    Button(action: {
                        if ttsManager.isSpeaking {
                            ttsManager.stop()
                        } else {
                            ttsManager.speak(text: "Bonjou, kijan ou rele?", language: "ht-HT")
                        }
                    }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Test Haitian Creole Voice")
                                    .font(.body)
                                    .foregroundColor(.primary)
                                Text("\"Bonjou, kijan ou rele?\"")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: ttsManager.isSpeaking ? "speaker.wave.3.fill" : "play.circle.fill")
                                .font(.title2)
                                .foregroundColor(.accentColor)
                        }
                        .padding(.vertical, 4)
                    }

                    // English test
                    Button(action: {
                        if ttsManager.isSpeaking {
                            ttsManager.stop()
                        } else {
                            ttsManager.speak(text: "Hello, how are you doing today?", language: "en-US")
                        }
                    }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Test English Voice")
                                    .font(.body)
                                    .foregroundColor(.primary)
                                Text("\"Hello, how are you doing today?\"")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: ttsManager.isSpeaking ? "speaker.wave.3.fill" : "play.circle.fill")
                                .font(.title2)
                                .foregroundColor(.accentColor)
                        }
                        .padding(.vertical, 4)
                    }

                    if ttsManager.isSpeaking {
                        Button(action: { ttsManager.stop() }) {
                            HStack {
                                Spacer()
                                Image(systemName: "stop.circle.fill")
                                    .font(.title2)
                                Text("Stop")
                                    .fontWeight(.semibold)
                                Spacer()
                            }
                            .foregroundColor(.red)
                            .padding(.vertical, 4)
                        }
                    }

                    if let error = ttsManager.lastError {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                } header: {
                    Label("Test Voice", systemImage: "ear")
                } footer: {
                    Text("Tap a button to preview the selected voice and speed.")
                        .font(.caption)
                }
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

    private var speedLabel: String {
        let s = voiceSettings.playbackSpeed
        switch s {
        case ..<0.65: return "Very Slow (\(String(format: "%.2f", s))×)"
        case ..<0.85: return "Slow (\(String(format: "%.2f", s))×)"
        case ..<1.1:  return "Normal (\(String(format: "%.2f", s))×)"
        case ..<1.3:  return "Fast (\(String(format: "%.2f", s))×)"
        default:      return "Very Fast (\(String(format: "%.2f", s))×)"
        }
    }
}

private struct VoiceRow: View {
    let voice: VoiceSettings.Voice
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(voice.name)
                        .font(.body)
                        .foregroundStyle(.primary)
                    Text(voice.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.body.weight(.semibold))
                        .foregroundColor(.accentColor)
                }
            }
        }
        .contentShape(Rectangle())
    }
}

#Preview {
    SettingsView(
        voiceSettings: VoiceSettings(),
        ttsManager: TextToSpeechManager()
    )
}
