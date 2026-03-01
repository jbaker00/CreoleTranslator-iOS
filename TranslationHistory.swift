//
//  TranslationHistory.swift
//  CreoleTranslator
//
//  Data model and storage for translation history
//

import Foundation

struct TranslationEntry: Identifiable, Codable, Equatable {
    let id: UUID
    let timestamp: Date
    let sourceText: String
    let translatedText: String
    let direction: TranslationDirection

    // Legacy support for old entries
    var creoleText: String {
        direction == .creoleToEnglish ? sourceText : translatedText
    }

    var englishText: String {
        direction == .creoleToEnglish ? translatedText : sourceText
    }

    init(id: UUID = UUID(), timestamp: Date = Date(), sourceText: String, translatedText: String, direction: TranslationDirection) {
        self.id = id
        self.timestamp = timestamp
        self.sourceText = sourceText
        self.translatedText = translatedText
        self.direction = direction
    }

    // Legacy initializer for backward compatibility
    init(id: UUID = UUID(), timestamp: Date = Date(), creoleText: String, englishText: String) {
        self.id = id
        self.timestamp = timestamp
        self.sourceText = creoleText
        self.translatedText = englishText
        self.direction = .creoleToEnglish
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }
}

@MainActor
class TranslationHistoryManager: ObservableObject {
    @Published private(set) var entries: [TranslationEntry] = []
    
    private let storageKey = "translationHistory"
    private let maxEntries = 50 // Limit to prevent storage bloat
    
    init() {
        loadHistory()
    }
    
    func addEntry(source: String, translated: String, direction: TranslationDirection) {
        // Don't save placeholder text
        guard !source.contains("Your transcription") && !translated.contains("Your translation") else {
            return
        }

        // Don't save empty entries
        guard !source.isEmpty && !translated.isEmpty else {
            return
        }

        let entry = TranslationEntry(sourceText: source, translatedText: translated, direction: direction)
        entries.insert(entry, at: 0) // Most recent first

        // Limit history size
        if entries.count > maxEntries {
            entries = Array(entries.prefix(maxEntries))
        }

        saveHistory()
    }

    // Legacy method for backward compatibility
    func addEntry(creole: String, english: String) {
        addEntry(source: creole, translated: english, direction: .creoleToEnglish)
    }
    
    func deleteEntry(_ entry: TranslationEntry) {
        entries.removeAll { $0.id == entry.id }
        saveHistory()
    }
    
    func clearAll() {
        entries = []
        saveHistory()
    }
    
    private func saveHistory() {
        if let encoded = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
    }
    
    private func loadHistory() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([TranslationEntry].self, from: data) else {
            return
        }
        entries = decoded
    }
}
