//
//  PhrasebookView.swift
//  CreoleTranslator
//
//  Offline common-phrases browser. Static content, speaker buttons only —
//  no network/LLM calls.
//

import SwiftUI

struct PhrasebookView: View {
    @StateObject private var ttsManager = TextToSpeechManager()
    @State private var direction: TranslationDirection = .englishToCreole

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 10) {
                HStack {
                    Text("Phrasebook")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Spacer()
                    Text("Works offline")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Same direction concept as the main translator — flips which
                // language is shown prominent/first for every phrase below.
                Button(action: {
                    withAnimation {
                        direction = direction == .englishToCreole ? .creoleToEnglish : .englishToCreole
                    }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.up.arrow.down")
                            .font(.system(size: 12))
                        Text(direction == .englishToCreole ? "English → Creole" : "Creole → English")
                            .font(.caption)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(UIColor.tertiarySystemBackground))
                    .foregroundColor(.accentColor)
                    .cornerRadius(14)
                }
            }
            .padding()
            .background(Color(UIColor.secondarySystemBackground))

            ScrollView {
                LazyVStack(spacing: 20, pinnedViews: [.sectionHeaders]) {
                    ForEach(Phrasebook.categories) { category in
                        Section {
                            VStack(spacing: 10) {
                                ForEach(category.entries) { entry in
                                    PhrasebookRow(entry: entry, direction: direction, ttsManager: ttsManager)
                                }
                            }
                        } header: {
                            HStack(spacing: 8) {
                                Image(systemName: category.icon)
                                    .foregroundColor(.accentColor)
                                Text(category.name)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                Spacer()
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 4)
                            .background(Color(UIColor.systemBackground))
                        }
                    }
                }
                .padding()
            }
        }
        .background(Color(UIColor.systemBackground))
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
    }
}

private struct PhrasebookRow: View {
    let entry: PhrasebookEntry
    let direction: TranslationDirection
    @ObservedObject var ttsManager: TextToSpeechManager
    @State private var isSpeakingThis = false

    // englishToCreole: English is the small "prompt" on top, Creole is the
    // prominent phrase below (the current default). creoleToEnglish flips
    // that — Creole is the prompt, English is what it means.
    private var promptText: String { direction == .englishToCreole ? entry.english : entry.creole }
    private var primaryText: String { direction == .englishToCreole ? entry.creole : entry.english }
    private var primaryLanguage: String { direction == .englishToCreole ? "ht-HT" : "en-US" }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(promptText)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text(primaryText)
                    .font(.body)
                    .foregroundColor(.primary)
            }
            Spacer()
            Button(action: {
                if ttsManager.isSpeaking {
                    ttsManager.stop()
                    isSpeakingThis = false
                } else {
                    isSpeakingThis = true
                    ttsManager.speak(text: primaryText, language: primaryLanguage)
                }
            }) {
                Image(systemName: isSpeakingThis ? "speaker.wave.3.fill" : "speaker.wave.2")
                    .font(.subheadline)
                    .foregroundColor(.accentColor)
            }
        }
        .padding(12)
        .background(Color(UIColor.tertiarySystemBackground))
        .cornerRadius(10)
        .onChange(of: ttsManager.isSpeaking) { speaking in
            if !speaking { isSpeakingThis = false }
        }
        .onChange(of: direction) { _ in
            if ttsManager.isSpeaking {
                ttsManager.stop()
            }
            isSpeakingThis = false
        }
    }
}

#Preview {
    PhrasebookView()
}
