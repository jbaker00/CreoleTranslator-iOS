//
//  HistoryView.swift
//  CreoleTranslator
//
//  History display view for past translations
//

import SwiftUI

struct HistoryView: View {
    @ObservedObject var historyManager: TranslationHistoryManager
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
                            HistoryEntryCard(entry: entry, historyManager: historyManager)
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
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header with timestamp
            HStack {
                Text(entry.formattedDate)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
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
                Text("🇭🇹")
                    .font(.title3)
                Text(entry.creoleText)
                    .font(.body)
                    .foregroundColor(.primary)
                    .lineLimit(isExpanded ? nil : 2)
            }
            
            Divider()
            
            // English translation
            HStack(alignment: .top, spacing: 8) {
                Text("🇺🇸")
                    .font(.title3)
                Text(entry.englishText)
                    .font(.body)
                    .foregroundColor(.primary)
                    .lineLimit(isExpanded ? nil : 2)
            }
            
            // Expand/collapse button if text is long
            if entry.creoleText.count > 100 || entry.englishText.count > 100 {
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
