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
    @State private var showFullScreen = false

    // englishToCreole: English is the small "prompt" on top, Creole is the
    // prominent phrase below (the current default). creoleToEnglish flips
    // that — Creole is the prompt, English is what it means.
    private var promptText: String { direction == .englishToCreole ? entry.english : entry.creole }
    private var primaryText: String { direction == .englishToCreole ? entry.creole : entry.english }
    private var primaryLanguage: String { direction == .englishToCreole ? "ht-HT" : "en-US" }

    // The legal-statement entry is a document to display, not a translated
    // phrase — its content always lives in `creole` regardless of direction.
    private var isDisplayStatement: Bool { entry.note != nil }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(promptText)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text(primaryText)
                    .font(.body)
                    .foregroundColor(.primary)
                if let note = entry.note {
                    Text(note)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.top, 2)
                    Label("Tap to show full screen — hold it up for someone to read", systemImage: "arrow.up.left.and.arrow.down.right")
                        .font(.caption2)
                        .foregroundColor(.accentColor)
                        .padding(.top, 2)
                }
            }
            Spacer()
            // The legal-statement entry is meant to be shown/handed over, not
            // spoken — and its "translation" is intentionally English either way.
            if entry.note == nil {
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
        }
        .padding(12)
        .background(Color(UIColor.tertiarySystemBackground))
        .cornerRadius(10)
        .contentShape(Rectangle())
        .onTapGesture {
            if isDisplayStatement { showFullScreen = true }
        }
        .fullScreenCover(isPresented: $showFullScreen) {
            FullScreenStatementView(text: entry.creole)
        }
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

// Full-screen, high-contrast display for text meant to be held up to a
// window or door for someone else to read — text auto-shrinks to fill the
// screen without scrolling, and reflows automatically if the phone is
// rotated (the app already supports both orientations).
private struct FullScreenStatementView: View {
    let text: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            Text(text)
                .font(.system(size: 100, weight: .bold))
                .minimumScaleFactor(0.05)
                .lineLimit(nil)
                .multilineTextAlignment(.center)
                .foregroundColor(.white)
                .padding(24)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            VStack {
                HStack {
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding()
                }
                Spacer()
            }
        }
        .statusBarHidden(true)
    }
}

#Preview {
    PhrasebookView()
}
