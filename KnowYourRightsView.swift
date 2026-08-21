//
//  KnowYourRightsView.swift
//  CreoleTranslator
//
//  Standalone safety-phrases screen. Static content, works offline — see
//  Phrasebook.knowYourRights for sourcing notes.
//

import SwiftUI

struct KnowYourRightsView: View {
    @StateObject private var ttsManager = TextToSpeechManager()
    @State private var direction: TranslationDirection = .englishToCreole

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 10) {
                HStack {
                    Label("Know Your Rights", systemImage: "hand.raised.fill")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Spacer()
                    Text("Works offline")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

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
                VStack(spacing: 10) {
                    ForEach(Phrasebook.knowYourRights) { entry in
                        PhrasebookRow(entry: entry, direction: direction, ttsManager: ttsManager)
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

#Preview {
    KnowYourRightsView()
}
