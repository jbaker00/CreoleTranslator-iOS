//
//  ContentView.swift
//  CreoleTranslator
//
//  Main UI for Creole to English Translator
//

import SwiftUI

struct ContentView: View {
    @StateObject private var audioRecorder = AudioRecorder()
    @Environment(\.colorScheme) private var colorScheme
    
    // Note: Secrets provides groqAPIKey, openAIKey, metaAPIKey and metaAPIURL
    private var groqAPIKey: String? { Secrets.groqAPIKey }
    private var openAIKey: String? { Secrets.openAIKey }
    private var metaAPIKey: String? { Secrets.metaAPIKey }
    private var metaAPIURL: URL? {
        if let s = Secrets.metaAPIURL, let url = URL(string: s) { return url }
        return nil
    }
    
    @State private var transcription = "Your transcription will appear here..."
    @State private var translation = "Your translation will appear here..."
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var recordingURL: URL?
    @State private var statusMessage = ""
    @State private var permissionGranted = false
    
    // Toggle to select which provider path to use: true = Groq (existing), false = OpenAI+Meta (direct)
    @State private var useGroqPath: Bool = true

    var body: some View {
        ZStack {
            // Adaptive background: branded gradient in light mode, subtle system backgrounds in dark mode
            let bgColors: [Color] = colorScheme == .dark
                ? [Color(UIColor.systemGray6), Color(UIColor.systemBackground)]
                : [Color(red: 0.4, green: 0.2, blue: 0.8), Color(red: 0.8, green: 0.3, blue: 0.5)]

            LinearGradient(
                colors: bgColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 30) {
                    // Header
                    VStack(spacing: 10) {
                        Text("🎤")
                            .font(.system(size: 60))
                        
                        Text("Creole to English")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        Text("Powered by Groq AI")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 40)
                    
                    // Provider switch
                    HStack {
                        Text("Use Groq path")
                            .font(.subheadline)
                            .foregroundColor(.primary)
                        Spacer()
                        Toggle(isOn: $useGroqPath) {
                            EmptyView()
                        }
                        .labelsHidden()
                    }
                    .padding(.horizontal, 30)
                    
                    // Recording button
                    Button(action: {
                        if audioRecorder.isRecording {
                            stopRecording()
                        } else {
                            startRecording()
                        }
                    }) {
                        HStack(spacing: 12) {
                            Text(audioRecorder.isRecording ? "⏹️" : "🎙️")
                                .font(.system(size: 24))
                            Text(audioRecorder.isRecording ? "Stop Recording" : "Start Recording")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        // Use system backgrounds so the button is visible in dark mode
                        .background(audioRecorder.isRecording ? Color.red : Color(UIColor.secondarySystemBackground))
                        .foregroundColor(audioRecorder.isRecording ? .white : Color.accentColor)
                        .cornerRadius(15)
                        .shadow(color: .black.opacity(0.2), radius: 10, y: 5)
                    }
                    .disabled(isProcessing || !permissionGranted)
                    .padding(.horizontal, 30)
                    
                    // Status message
                    if !statusMessage.isEmpty {
                        Text(statusMessage)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                            .padding(.horizontal)
                    }
                    
                    // Processing indicator
                    if isProcessing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .accentColor))
                            .scaleEffect(1.5)
                            .padding()
                    }
                    
                    // Results section
                    VStack(spacing: 20) {
                        ResultCard(
                            title: "Haitian Creole",
                            icon: "🇭🇹",
                            content: transcription,
                            isLoading: isProcessing
                        )
                        
                        ResultCard(
                            title: "English Translation",
                            icon: "🇺🇸",
                            content: translation,
                            isLoading: isProcessing
                        )
                    }
                    .padding(.horizontal, 20)
                    
                    // Error message
                    if let error = errorMessage {
                        Text(error)
                            .font(.subheadline)
                            .foregroundColor(.red)
                            .padding()
                            .background(Color(UIColor.systemBackground).opacity(0.95))
                            .cornerRadius(10)
                            .padding(.horizontal, 30)
                    }
                    
                    Spacer(minLength: 30)
                }
            }
        }
        .onAppear {
            checkMicrophonePermission()
            // Warn user if API key is missing so they know to add it before using the network features.
            if groqAPIKey == nil {
                errorMessage = "Missing Groq API key. Add GROQ_API_KEY to a gitignored Secrets.plist or set the GROQ_API_KEY environment variable in your Xcode scheme."
            }
        }
    }
    
    private func checkMicrophonePermission() {
        audioRecorder.requestPermission { granted in
            permissionGranted = granted
            if !granted {
                errorMessage = "Microphone access denied. Please enable it in Settings."
            }
        }
    }
    
    private func startRecording() {
        errorMessage = nil
        statusMessage = "🔴 Recording..."
        recordingURL = audioRecorder.startRecording()
    }
    
    private func stopRecording() {
        guard let url = audioRecorder.stopRecording() else {
            errorMessage = "Failed to stop recording"
            return
        }
        
        recordingURL = url
        statusMessage = "⏳ Processing..."
        processAudio(url: url)
    }
    
    private func processAudio(url: URL) {
        // Choose service implementation depending on toggle
        let service: TranslationService
        if useGroqPath {
            guard let apiKey = groqAPIKey, !apiKey.isEmpty else {
                errorMessage = "Missing Groq API key. Add GROQ_API_KEY to Secrets.plist or set the environment variable in your scheme."
                return
            }
            service = GroqService(apiKey: apiKey)
        } else {
            // OpenAI + Meta path
            guard let oKey = openAIKey, !oKey.isEmpty else {
                errorMessage = "Missing OpenAI API key. Set OPENAI_API_KEY in Secrets.plist or Xcode scheme."
                return
            }
            // metaAPIURL is required (can be HuggingFace inference URL or self-hosted)
            guard let mURL = metaAPIURL else {
                errorMessage = "Missing META_API_URL. Set META_API_URL to the Meta/Llama endpoint (or HuggingFace model URL)."
                return
            }
            let mKey = metaAPIKey // optional depending on host
            service = OpenAIMetaService(openAIKey: oKey, metaKey: mKey, metaURL: mURL)
        }
        
        isProcessing = true
        transcription = "Processing..."
        translation = "Waiting..."
        
        Task {
            do {
                let result = try await service.processAudio(fileURL: url)
                
                await MainActor.run {
                    transcription = result.transcription
                    translation = result.translation
                    statusMessage = "✅ Completed using \(result.provider)"
                    isProcessing = false
                }
                
                audioRecorder.deleteRecording(at: url)
            } catch {
                await MainActor.run {
                    transcription = "Your transcription will appear here..."
                    translation = "Your translation will appear here..."
                    errorMessage = "Error: \(error.localizedDescription)"
                    statusMessage = ""
                    isProcessing = false
                }
                audioRecorder.deleteRecording(at: url)
            }
        }
    }
}

struct ResultCard: View {
    let title: String
    let icon: String
    let content: String
    let isLoading: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(icon)
                    .font(.title2)
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            
            Text(content)
                .font(.body)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .opacity(isLoading && content == "Processing..." ? 0.6 : 1.0)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(Color(UIColor.tertiarySystemBackground))
        .cornerRadius(15)
        .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
    }
}

#Preview {
    ContentView()
}
