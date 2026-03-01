//
//  ContentView.swift
//  CreoleTranslator
//
//  Main UI for Creole to English Translator
//

import SwiftUI

struct ContentView: View {
    @StateObject private var audioRecorder = AudioRecorder()
    @StateObject private var historyManager = TranslationHistoryManager()
    @StateObject private var ttsManager = TextToSpeechManager(apiKey: Secrets.apiKey)
    @Environment(\.colorScheme) private var colorScheme
    
    // Use the centralized Secrets helper to load the API key.
    private let groqAPIKey: String? = Secrets.apiKey
    
    @State private var transcription = "Your transcription will appear here..."
    @State private var translation = "Your translation will appear here..."
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var recordingURL: URL?
    @State private var statusMessage = ""
    @State private var permissionGranted = false
    @State private var availableWidth: CGFloat = 320
    @State private var showHistory = false
    @State private var speakingCardTitle: String? = nil
    
    var body: some View {
        // ZStack allows us to overlay the banner at the bottom while content scrolls above
        ZStack(alignment: .bottom) {
            // Gradient background
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
                        HStack {
                            Spacer()
                            
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
                            
                            Spacer()
                            
                            // History button
                            VStack {
                                Button(action: {
                                    withAnimation {
                                        showHistory.toggle()
                                    }
                                }) {
                                    ZStack {
                                        Circle()
                                            .fill(Color(UIColor.secondarySystemBackground))
                                            .frame(width: 44, height: 44)
                                        
                                        Image(systemName: showHistory ? "xmark" : "clock.arrow.circlepath")
                                            .font(.system(size: 20))
                                            .foregroundColor(.accentColor)
                                    }
                                }
                                
                                if !historyManager.entries.isEmpty {
                                    Text("\(historyManager.entries.count)")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.top, 40)
                    
                    // Show history or main content
                    if showHistory {
                        HistoryView(historyManager: historyManager)
                            .padding(.horizontal, 20)
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                    } else {
                        mainContentView
                            .transition(.move(edge: .leading).combined(with: .opacity))
                    }
                    
                    Spacer(minLength: 80) // leave room for banner
                }
            }
            .onAppear {
                checkMicrophonePermission()
                // Warn user if API key is missing so they know to add it before using the network features.
                if groqAPIKey == nil {
                    errorMessage = "Missing Groq API key. Add GROQ_API_KEY to a gitignored Secrets.plist or set the GROQ_API_KEY environment variable in your Xcode scheme. See README for setup."
                }
            }
            
            // Host the banner in a GeometryReader so we can pass the current width to compute an adaptive size.
            GeometryReader { geo in
                BannerAdView(width: geo.size.width)
                    .frame(width: geo.size.width, height: 50, alignment: .center) // Reserve typical banner height; adaptive banners may adjust internally
                    .background(Color(UIColor.tertiarySystemBackground)) // Use system background color for consistent contrast
                    .overlay(alignment: .top) { Divider() } // Subtle divider to delineate content and ad area
                    .ignoresSafeArea(edges: .bottom) // Allow the banner to extend to the bottom edge safely
                    .onAppear { availableWidth = geo.size.width } // Initialize width on first layout
                    .onChange(of: geo.size.width) { newWidth in availableWidth = newWidth } // Update width as the device rotates or layout changes
            }
            .frame(height: 50, alignment: .bottom) // Constrain the GeometryReader's height so it doesn't take over the layout
        }
    }
    
    // Main content view extracted for cleaner code
    private var mainContentView: some View {
        VStack(spacing: 30) {
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
                    isLoading: isProcessing,
                    speakerAction: {
                        if ttsManager.isSpeaking {
                            ttsManager.stop()
                            speakingCardTitle = nil
                        } else {
                            speakingCardTitle = "creole"
                            ttsManager.speak(text: transcription, language: "ht-HT")
                        }
                    },
                    isSpeaking: ttsManager.isSpeaking && speakingCardTitle == "creole"
                )

                ResultCard(
                    title: "English Translation",
                    icon: "🇺🇸",
                    content: translation,
                    isLoading: isProcessing,
                    speakerAction: {
                        if ttsManager.isSpeaking {
                            ttsManager.stop()
                            speakingCardTitle = nil
                        } else {
                            speakingCardTitle = "english"
                            ttsManager.speak(text: translation)
                        }
                    },
                    isSpeaking: ttsManager.isSpeaking && speakingCardTitle == "english"
                )
            }
            .padding(.horizontal, 20)
            .onChange(of: ttsManager.isSpeaking) { speaking in
                if !speaking {
                    speakingCardTitle = nil
                }
            }
            
            // TTS error message (helps diagnose Groq TTS fallback issues)
            if let ttsError = ttsManager.lastError {
                Text(ttsError)
                    .font(.caption)
                    .foregroundColor(.orange)
                    .padding()
                    .background(Color(UIColor.systemBackground).opacity(0.95))
                    .cornerRadius(10)
                    .padding(.horizontal, 30)
            }

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
            
            Spacer(minLength: 80) // leave room for banner
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
        // Guard that we have an API key before performing network calls
        guard let apiKey = groqAPIKey, !apiKey.isEmpty else {
            errorMessage = "Missing Groq API key. Add GROQ_API_KEY to Secrets.plist or set the environment variable in your scheme."
            statusMessage = ""
            return
        }
        
        isProcessing = true
        transcription = "Processing..."
        translation = "Waiting..."
        
        Task {
            do {
                let groqService = GroqService(apiKey: apiKey)
                let result = try await groqService.processAudio(fileURL: url)
                
                await MainActor.run {
                    transcription = result.transcription
                    translation = result.translation
                    statusMessage = "✅ Completed using \(result.provider)"
                    isProcessing = false
                    
                    // Save to history
                    historyManager.addEntry(creole: result.transcription, english: result.translation)
                }
                
                // Clean up audio file
                audioRecorder.deleteRecording(at: url)
                
            } catch {
                await MainActor.run {
                    transcription = "Your transcription will appear here..."
                    translation = "Your translation will appear here..."
                    errorMessage = "Error: \(error.localizedDescription)"
                    statusMessage = ""
                    isProcessing = false
                }
                
                // Clean up audio file
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
    var speakerAction: (() -> Void)? = nil
    var isSpeaking: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(icon)
                    .font(.title2)
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)

                Spacer()

                // Show speaker button if speakerAction is provided
                if let action = speakerAction {
                    Button(action: action) {
                        Image(systemName: isSpeaking ? "speaker.wave.3.fill" : "speaker.wave.2")
                            .font(.title3)
                            .foregroundColor(.accentColor)
                            .padding(8)
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(8)
                    }
                    .disabled(content.contains("Your translation") || content.contains("Your transcription") || content == "Waiting..." || content == "Processing..." || content.isEmpty)
                }
            }

            Text(content)
                .font(.body)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .opacity(isLoading && content == "Processing..." ? 0.6 : 1.0)
        }
        .padding(20)
        // Use a system background for cards so they contrast correctly in both appearances
        .background(Color(UIColor.tertiarySystemBackground))
        .cornerRadius(15)
        .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
    }
}

#Preview {
    ContentView()
}
