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
    let creoleText: String
    let englishText: String
    
    init(id: UUID = UUID(), timestamp: Date = Date(), creoleText: String, englishText: String) {
        self.id = id
        self.timestamp = timestamp
        self.creoleText = creoleText
        self.englishText = englishText
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
    
    func addEntry(creole: String, english: String) {
        // Don't save placeholder text
        guard !creole.contains("Your transcription") && !english.contains("Your translation") else {
            return
        }
        
        // Don't save empty entries
        guard !creole.isEmpty && !english.isEmpty else {
            return
        }
        
        let entry = TranslationEntry(creoleText: creole, englishText: english)
        entries.insert(entry, at: 0) // Most recent first
        
        // Limit history size
        if entries.count > maxEntries {
            entries = Array(entries.prefix(maxEntries))
        }
        
        saveHistory()
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
