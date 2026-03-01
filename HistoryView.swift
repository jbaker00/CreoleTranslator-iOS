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
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
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
            } else {
                // History list
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(historyManager.entries) { entry in
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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header with timestamp
            HStack {
                Text(entry.formattedDate)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                // Speaker button
                Button(action: {
                    if ttsManager.isSpeaking {
                        ttsManager.stop()
                    } else {
                        let language = entry.direction == .creoleToEnglish ? "en-US" : "ht-HT"
                        ttsManager.speak(text: entry.translatedText, language: language)
                    }
                }) {
                    Image(systemName: ttsManager.isSpeaking ? "speaker.wave.3.fill" : "speaker.wave.2")
                        .font(.caption)
                        .foregroundColor(.accentColor)
                }

                // Delete button
                Button(action: {
                    historyManager.deleteEntry(entry)
                }) {
                    Image(systemName: "trash")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            
            // Creole text
            HStack(alignment: .top, spacing: 8) {
                Text(entry.direction == .creoleToEnglish ? "🇭🇹" : "🇺🇸")
                    .font(.title3)
                Text(entry.sourceText)
                    .font(.body)
                    .foregroundColor(.primary)
                    .lineLimit(isExpanded ? nil : 2)
            }

            Divider()

            // English translation
            HStack(alignment: .top, spacing: 8) {
                Text(entry.direction == .creoleToEnglish ? "🇺🇸" : "🇭🇹")
                    .font(.title3)
                Text(entry.translatedText)
                    .font(.body)
                    .foregroundColor(.primary)
                    .lineLimit(isExpanded ? nil : 2)
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
    }
}
