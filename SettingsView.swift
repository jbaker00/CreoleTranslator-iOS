//
//  SettingsView.swift
//  CreoleTranslator
//
//  Options screen for selecting TTS voices per language.
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject var voiceSettings: VoiceSettings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            Form {
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
                    Label("English Voice (Groq TTS)", systemImage: "waveform")
                } footer: {
                    Text("Used when playing English text.")
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
                    Image(systemName: "checkmark")
                        .font(.body.weight(.semibold))
                        .foregroundColor(.accentColor)
                }
            }
        }
        .contentShape(Rectangle())
    }
}

#Preview {
    SettingsView(voiceSettings: VoiceSettings())
}
