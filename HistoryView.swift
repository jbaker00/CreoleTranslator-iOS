//
//  HistoryView.swift
//  CreoleTranslator
//
//  History display view for past translations
//

import SwiftUI

struct HistoryView: View {
    @ObservedObject var historyManager: TranslationHistoryManager
    @StateObject private var ttsManager = TextToSpeechManager()
    @Environment(\.colorScheme) private var colorScheme
    @State private var favoritesOnly = false

    private var displayedEntries: [TranslationEntry] {
        favoritesOnly ? historyManager.entries.filter(\.isFavorite) : historyManager.entries
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 10) {
                HStack {
                    Text("Translation History")
                        .font(.headline)
                        .foregroundColor(.primary)

                    Spacer()

                    if !historyManager.entries.isEmpty {
                        Button(action: {
                            historyManager.clearAll()
                        }) {
                            Text("Clear All")
                                .font(.subheadline)
                                .foregroundColor(.red)
                        }
                    }
                }

                if !historyManager.entries.isEmpty {
                    HStack {
                        Button(action: { favoritesOnly.toggle() }) {
                            HStack(spacing: 6) {
                                Image(systemName: favoritesOnly ? "star.fill" : "star")
                                Text("Favorites only")
                            }
                            .font(.subheadline)
                            .foregroundColor(favoritesOnly ? .yellow : .secondary)
                        }
                        Spacer()
                    }
                }
            }
            .padding()
            .background(Color(UIColor.secondarySystemBackground))

            if historyManager.entries.isEmpty {
                // Empty state
                VStack(spacing: 15) {
                    Text("📝")
                        .font(.system(size: 50))
                    Text("No translation history yet")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("Your translations will appear here")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxHeight: .infinity)
                .padding()
            } else if displayedEntries.isEmpty {
                // No favorites yet
                VStack(spacing: 15) {
                    Text("⭐️")
                        .font(.system(size: 50))
                    Text("No favorites yet")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("Tap the star on a translation to save it here")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxHeight: .infinity)
                .padding()
            } else {
                // History list
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(displayedEntries) { entry in
                            HistoryEntryCard(
                                entry: entry,
                                historyManager: historyManager,
                                ttsManager: ttsManager
                            )
                        }
                    }
                    .padding()
                }
            }
        }
        .background(Color(UIColor.systemBackground))
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
    }
}

struct HistoryEntryCard: View {
    let entry: TranslationEntry
    @ObservedObject var historyManager: TranslationHistoryManager
    @ObservedObject var ttsManager: TextToSpeechManager
    @State private var isExpanded = false
    @State private var speakingRow: String? = nil // "source" or "translated"

    private func speakerButton(row: String, text: String, language: String) -> some View {
        let isThisRowSpeaking = ttsManager.isSpeaking && speakingRow == row
        return Button(action: {
            if ttsManager.isSpeaking {
                ttsManager.stop()
                speakingRow = nil
            } else {
                speakingRow = row
                ttsManager.speak(text: text, language: language)
            }
        }) {
            Image(systemName: isThisRowSpeaking ? "speaker.wave.3.fill" : "speaker.wave.2")
                .font(.caption)
                .foregroundColor(.accentColor)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header with timestamp, favorite star, and delete
            HStack {
                Text(entry.formattedDate)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Button(action: { historyManager.toggleFavorite(entry) }) {
                    Image(systemName: entry.isFavorite ? "star.fill" : "star")
                        .font(.caption)
                        .foregroundColor(entry.isFavorite ? .yellow : .secondary)
                }

                Button(action: { historyManager.deleteEntry(entry) }) {
                    Image(systemName: "trash")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }

            // Source text row with speaker
            HStack(alignment: .top, spacing: 8) {
                Text(entry.direction == .creoleToEnglish ? "🇭🇹" : "🇺🇸")
                    .font(.title3)
                Text(entry.sourceText)
                    .font(.body)
                    .foregroundColor(.primary)
                    .lineLimit(isExpanded ? nil : 2)
                Spacer()
                speakerButton(
                    row: "source",
                    text: entry.sourceText,
                    language: entry.direction == .creoleToEnglish ? "ht-HT" : "en-US"
                )
            }

            Divider()

            // Translated text row with speaker
            HStack(alignment: .top, spacing: 8) {
                Text(entry.direction == .creoleToEnglish ? "🇺🇸" : "🇭🇹")
                    .font(.title3)
                Text(entry.translatedText)
                    .font(.body)
                    .foregroundColor(.primary)
                    .lineLimit(isExpanded ? nil : 2)
                Spacer()
                speakerButton(
                    row: "translated",
                    text: entry.translatedText,
                    language: entry.direction == .creoleToEnglish ? "en-US" : "ht-HT"
                )
            }

            // Expand/collapse button if text is long
            if entry.sourceText.count > 100 || entry.translatedText.count > 100 {
                Button(action: {
                    withAnimation {
                        isExpanded.toggle()
                    }
                }) {
                    Text(isExpanded ? "Show less" : "Show more")
                        .font(.caption)
                        .foregroundColor(.accentColor)
                }
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
        .onChange(of: ttsManager.isSpeaking) { speaking in
            if !speaking { speakingRow = nil }
        }
    }
}
