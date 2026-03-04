//
//  SettingsView.swift
//  CreoleTranslator
//
//  Options screen for selecting TTS voices per language.
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject var voiceSettings: VoiceSettings
    @ObservedObject var privacyConsent: DataPrivacyConsent
    @Environment(\.dismiss) private var dismiss
    @State private var showPrivacyAlert = false

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

                Section {
                    HStack {
                        Label("Data Sharing Consent", systemImage: "shield.checkered")
                        Spacer()
                        Text(privacyConsent.hasConsented ? "Granted" : "Not Granted")
                            .font(.subheadline)
                            .foregroundColor(privacyConsent.hasConsented ? .green : .red)
                    }

                    Button(action: {
                        showPrivacyAlert = true
                    }) {
                        HStack {
                            Text("Review Privacy Notice")
                            Spacer()
                            Image(systemName: "arrow.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Label("Privacy & Data Sharing", systemImage: "hand.raised")
                } footer: {
                    Text("This app shares your audio recordings with Groq AI (for transcription and translation) and OpenAI (for text-to-speech). You can review or revoke consent at any time.")
                        .font(.caption)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Data Privacy Notice", isPresented: $showPrivacyAlert) {
                if privacyConsent.hasConsented {
                    Button("Revoke Consent", role: .destructive) {
                        privacyConsent.revokeConsent()
                    }
                } else {
                    Button("Grant Consent") {
                        privacyConsent.grantConsent()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This app shares your audio recordings with Groq AI (for transcription and translation) and OpenAI (for text-to-speech). Audio is processed temporarily and not stored on your device.\n\nYou can revoke this consent at any time, but app features will be disabled until consent is granted again.")
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
    SettingsView(voiceSettings: VoiceSettings(), privacyConsent: DataPrivacyConsent())
}
