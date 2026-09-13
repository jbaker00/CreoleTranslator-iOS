//
//  ContentView.swift
//  CreoleTranslator
//
//  Main UI for Creole to English Translator
//

import FirebaseAnalytics
import StoreKit
import SwiftUI

struct ContentView: View {
    @StateObject private var audioRecorder = AudioRecorder()
    @StateObject private var historyManager = TranslationHistoryManager()
    @StateObject private var voiceSettings = VoiceSettings()
    @StateObject private var ttsManager = TextToSpeechManager()
    @StateObject private var privacyConsent = DataPrivacyConsent()
    @StateObject private var interstitialAd = InterstitialAdManager()
    @Environment(\.colorScheme) private var colorScheme

    // Use the centralized Secrets helper to load the API key.

    @State private var transcription = "Your transcription will appear here..."
    @State private var translation = "Your translation will appear here..."
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var recordingURL: URL?
    @State private var statusMessage = ""
    @State private var permissionGranted = false
    @State private var availableWidth: CGFloat = 320
    @State private var showHistory = false
    @State private var showPhrasebook = false
    @State private var showSettings = false
    @State private var translationDirection: TranslationDirection = .creoleToEnglish
    @State private var speakingCardTitle: String? = nil
    @State private var typedInput = ""
    @State private var inputMode: InputMode = .voice
    // Proxy sample id of the translation on screen (nil = nothing to rate)
    // and the rating already sent for it, so the thumbs lock after one tap.
    @State private var currentSampleId: String? = nil
    @State private var sentRating: String? = nil
    /// Direction the current result was actually translated in (differs
    /// from translationDirection after an auto-detect flip). nil = no result.
    @State private var resultDirection: TranslationDirection? = nil
    @State private var autoDetectedFlip = false
    /// What produced the current result, so Undo can redo it manually.
    @State private var lastInput: (text: String, source: TranslationSource)? = nil
    @AppStorage("successfulTranslationCount") private var successfulTranslationCount = 0
    @AppStorage("lastReviewPromptVersion") private var lastReviewPromptVersion = ""

    enum InputMode {
        case voice, text
    }
    
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

                                Text(translationDirection == .creoleToEnglish ? "Creole to English" : "English to Creole")
                                    .font(.title)
                                    .fontWeight(.bold)
                                    .foregroundColor(.primary)

                                Text("Powered by Groq AI")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            // History + Phrasebook + Settings buttons
                            VStack(spacing: 8) {
                                Button(action: {
                                    withAnimation {
                                        showPhrasebook = false
                                        showHistory.toggle()
                                    }
                                    if showHistory {
                                        Analytics.logEvent(AnalyticsEventScreenView, parameters: [
                                            AnalyticsParameterScreenName: "history",
                                        ])
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

                                Button(action: {
                                    withAnimation {
                                        showHistory = false
                                        showPhrasebook.toggle()
                                    }
                                    if showPhrasebook {
                                        Analytics.logEvent(AnalyticsEventScreenView, parameters: [
                                            AnalyticsParameterScreenName: "phrasebook",
                                        ])
                                    }
                                }) {
                                    ZStack {
                                        Circle()
                                            .fill(Color(UIColor.secondarySystemBackground))
                                            .frame(width: 44, height: 44)

                                        Image(systemName: showPhrasebook ? "xmark" : "book.fill")
                                            .font(.system(size: 20))
                                            .foregroundColor(.accentColor)
                                    }
                                }

                                Button(action: {
                                    showSettings = true
                                    Analytics.logEvent(AnalyticsEventScreenView, parameters: [
                                        AnalyticsParameterScreenName: "settings",
                                    ])
                                }) {
                                    ZStack {
                                        Circle()
                                            .fill(Color(UIColor.secondarySystemBackground))
                                            .frame(width: 44, height: 44)

                                        Image(systemName: "gearshape")
                                            .font(.system(size: 20))
                                            .foregroundColor(.accentColor)
                                    }
                                }

                                Spacer()
                            }
                            .sheet(isPresented: $showSettings) {
                                SettingsView(voiceSettings: voiceSettings, ttsManager: ttsManager, privacyConsent: privacyConsent)
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.top, 40)

                    // Show history, phrasebook, or main content
                    if showHistory {
                        HistoryView(historyManager: historyManager)
                            .padding(.horizontal, 20)
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                    } else if showPhrasebook {
                        PhrasebookView()
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
                // Returning users never see the consent sheet, so ask ATT
                // here; first-run users get it after the sheet (see below).
                // Resolving ATT early keeps banner requests personalized.
                if privacyConsent.hasConsented {
                    ATTAuthorization.requestIfNeeded()
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
        .sheet(isPresented: Binding(
            get: { privacyConsent.shouldShowConsentDialog },
            set: { _ in }
        )) {
            DataPrivacyConsentView(consentManager: privacyConsent)
        }
        .onChange(of: privacyConsent.hasConsented) { consented in
            if consented { ATTAuthorization.requestIfNeeded() }
        }
    }
    
    // Main content view extracted for cleaner code
    private var mainContentView: some View {
        VStack(spacing: 30) {
            // Input mode picker
            Picker("Input Mode", selection: $inputMode) {
                Label("Voice", systemImage: "mic.fill").tag(InputMode.voice)
                Label("Type", systemImage: "keyboard").tag(InputMode.text)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 30)
            .disabled(isProcessing || audioRecorder.isRecording)

            if inputMode == .voice {
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
                .disabled(isProcessing || !privacyConsent.hasConsented)
                .padding(.horizontal, 30)
            } else {
                // Text input
                VStack(spacing: 12) {
                    let inputLabel = translationDirection == .creoleToEnglish ? "Enter Haitian Creole text..." : "Enter English text..."
                    TextEditor(text: $typedInput)
                        .frame(minHeight: 100, maxHeight: 160)
                        .padding(10)
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(UIColor.separator), lineWidth: 1)
                        )
                        .overlay(alignment: .topLeading) {
                            if typedInput.isEmpty {
                                Text(inputLabel)
                                    .foregroundColor(Color(UIColor.placeholderText))
                                    .padding(.top, 18)
                                    .padding(.leading, 14)
                                    .allowsHitTesting(false)
                            }
                        }
                        .disabled(isProcessing || !privacyConsent.hasConsented)

                    Button(action: { submitTypedText() }) {
                        HStack(spacing: 10) {
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.system(size: 20))
                            Text("Translate")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(typedInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isProcessing || !privacyConsent.hasConsented
                            ? Color(UIColor.tertiarySystemBackground)
                            : Color.accentColor)
                        .foregroundColor(typedInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isProcessing || !privacyConsent.hasConsented
                            ? Color(UIColor.placeholderText)
                            : .white)
                        .cornerRadius(15)
                        .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
                    }
                    .disabled(typedInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isProcessing || !privacyConsent.hasConsented)
                }
                .padding(.horizontal, 30)
            }
            
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
                // Source language card
                let shownDirection = resultDirection ?? translationDirection
                let sourceLanguage = shownDirection == .creoleToEnglish ? "ht-HT" : "en-US"
                ResultCard(
                    title: shownDirection == .creoleToEnglish ? "Haitian Creole" : "English",
                    icon: shownDirection == .creoleToEnglish ? "🇭🇹" : "🇺🇸",
                    content: transcription,
                    isLoading: isProcessing,
                    speakerAction: {
                        if ttsManager.isSpeaking {
                            ttsManager.stop()
                            speakingCardTitle = nil
                        } else {
                            speakingCardTitle = "source"
                            ttsManager.speak(text: transcription, language: sourceLanguage)
                        }
                    },
                    isSpeaking: ttsManager.isSpeaking && speakingCardTitle == "source"
                )

                if autoDetectedFlip, let shown = resultDirection {
                    HStack(spacing: 8) {
                        Image(systemName: "wand.and.stars")
                            .font(.system(size: 12))
                        Text("Auto-detected \(shown == .creoleToEnglish ? "Creole → English" : "English → Creole")")
                            .font(.caption)
                        Text("·").font(.caption).foregroundColor(.secondary)
                        Button("Undo") { undoAutoDetect() }
                            .font(.caption.bold())
                            .disabled(isProcessing)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.accentColor.opacity(0.12))
                    .foregroundColor(.accentColor)
                    .cornerRadius(14)
                }

                // Switch Direction button between the two cards
                Button(action: {
                    withAnimation {
                        translationDirection = translationDirection == .creoleToEnglish ? .englishToCreole : .creoleToEnglish
                        // A manual switch re-labels the cards; the result no longer belongs to a detected direction.
                        resultDirection = nil
                        autoDetectedFlip = false
                    }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.up.arrow.down")
                            .font(.system(size: 14))
                        Text("Switch Direction")
                            .font(.subheadline)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color(UIColor.secondarySystemBackground))
                    .foregroundColor(.accentColor)
                    .cornerRadius(20)
                }
                .disabled(isProcessing)

                // Target language card
                let targetLanguage = shownDirection == .creoleToEnglish ? "en-US" : "ht-HT"
                ResultCard(
                    title: shownDirection == .creoleToEnglish ? "English Translation" : "Creole Translation",
                    icon: shownDirection == .creoleToEnglish ? "🇺🇸" : "🇭🇹",
                    content: translation,
                    isLoading: isProcessing,
                    speakerAction: {
                        if ttsManager.isSpeaking {
                            ttsManager.stop()
                            speakingCardTitle = nil
                        } else {
                            speakingCardTitle = "target"
                            ttsManager.speak(text: translation, language: targetLanguage)
                        }
                    },
                    isSpeaking: ttsManager.isSpeaking && speakingCardTitle == "target",
                    feedbackSampleId: isProcessing ? nil : currentSampleId,
                    sentRating: sentRating,
                    onFeedback: { rating in
                        guard let id = currentSampleId, sentRating == nil else { return }
                        sentRating = rating
                        Analytics.logEvent("translation_feedback", parameters: ["rating": rating])
                        Task { await GroqService().sendFeedback(sampleId: id, rating: rating) }
                    }
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
    
    private func startRecording() {
        errorMessage = nil
        // Ask for mic access on first record tap — in context, the user
        // understands exactly why the prompt is appearing.
        audioRecorder.requestPermission { granted in
            permissionGranted = granted
            guard granted else {
                errorMessage = "Microphone access denied. Please enable it in Settings."
                return
            }
            statusMessage = "🔴 Recording..."
            recordingURL = audioRecorder.startRecording()
        }
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
    
    private func submitTypedText() {
        let text = typedInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        errorMessage = nil
        statusMessage = "⏳ Translating..."
        processTextInput(text)
    }

    /// Applies the auto-detect setting: returns the direction to translate
    /// `text` in, given the user's chosen direction.
    private static func detectedDirection(for text: String, manual: TranslationDirection, autoDetectEnabled: Bool) -> TranslationDirection {
        guard autoDetectEnabled else { return manual }
        switch LanguageDetector.detect(text) {
        case .creole:  return .creoleToEnglish
        case .english: return .englishToCreole
        case .unknown: return manual
        }
    }

    private func undoAutoDetect() {
        guard let input = lastInput else { return }
        Analytics.logEvent("auto_detect_undo", parameters: ["direction": directionCode])
        processTextInput(input.text, source: input.source, allowAutoDetect: false)
    }

    private func processTextInput(_ text: String, source: TranslationSource = .typed, allowAutoDetect: Bool = true) {
        isProcessing = true
        transcription = "Processing..."
        translation = "Waiting..."
        let direction = Self.detectedDirection(for: text, manual: translationDirection,
                                               autoDetectEnabled: allowAutoDetect && voiceSettings.autoDetectLanguage)
        let flipped = direction != translationDirection

        Task {
            do {
                let groqService = GroqService()
                let result = try await groqService.processText(text, direction: direction, source: source)

                await MainActor.run {
                    transcription = result.transcription
                    translation = result.translation
                    currentSampleId = result.sampleId
                    sentRating = nil
                    resultDirection = result.direction
                    autoDetectedFlip = flipped
                    lastInput = (text, source)
                    if flipped { Analytics.logEvent("auto_detect_flip", parameters: ["input_mode": source.rawValue]) }
                    statusMessage = "✅ Completed using \(result.provider)"
                    isProcessing = false
                    historyManager.addEntry(source: result.transcription, translated: result.translation, direction: result.direction)
                    logTranslationCompleted(inputMode: "text", charLength: text.count)
                    maybeRequestReview()
                    interstitialAd.translationCompleted(isSpeaking: ttsManager.isSpeaking)
                }
            } catch {
                await MainActor.run {
                    transcription = "Your transcription will appear here..."
                    translation = "Your translation will appear here..."
                    errorMessage = "Error: \(error.localizedDescription)"
                    statusMessage = ""
                    isProcessing = false
                    currentSampleId = nil
                    resultDirection = nil
                    autoDetectedFlip = false
                    logTranslationFailed(inputMode: "text", error: error)
                }
            }
        }
    }

    // Fires at the 3rd lifetime success, once per app version — one
    // translation before the first interstitial (4th), so the rating
    // sheet never lands on top of a full-screen ad.
    private func maybeRequestReview() {
        successfulTranslationCount += 1
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        guard successfulTranslationCount >= 3, lastReviewPromptVersion != version else { return }
        lastReviewPromptVersion = version
        // Matches Android's AnalyticsManager.logReviewRequested: the prompt
        // fires once per version, so this is what makes the rate measurable.
        Analytics.logEvent("review_requested", parameters: ["version": version])
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if let scene = UIApplication.shared.connectedScenes
                .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
                SKStoreReviewController.requestReview(in: scene)
            }
        }
    }

    /// Mirrors Android's AnalyticsManager.logTranslation / logTranslationFailed
    /// so both platforms answer the same questions in GA4. `char_length` and
    /// `result` were iOS-side gaps; `error` only applies to the failure path.
    ///
    /// `direction` deliberately keeps its existing iOS spelling — FirebaseViewer
    /// folds creole_to_english and ht-en onto one row, and changing it here
    /// would orphan every event logged before this release.
    private var directionCode: String {
        translationDirection == .creoleToEnglish ? "creole_to_english" : "english_to_creole"
    }

    private func logTranslationCompleted(inputMode: String, charLength: Int) {
        Analytics.logEvent("translation_completed", parameters: [
            "direction": directionCode,
            "input_mode": inputMode,
            "char_length": charLength,
            "result": "success",
        ])
    }

    private func logTranslationFailed(inputMode: String, error: Error) {
        Analytics.logEvent("translation_failed", parameters: [
            "direction": directionCode,
            "input_mode": inputMode,
            "error": String(error.localizedDescription.prefix(100)),
        ])
    }

    private func processAudio(url: URL) {
        isProcessing = true
        transcription = "Processing..."
        translation = "Waiting..."

        Task {
            do {
                let groqService = GroqService()
                let manual = translationDirection
                let autoDetect = voiceSettings.autoDetectLanguage   // read on the main actor, used off it
                let result = try await groqService.processAudio(fileURL: url, direction: manual) { transcript in
                    Self.detectedDirection(for: transcript, manual: manual, autoDetectEnabled: autoDetect)
                }
                let flipped = result.direction != manual

                await MainActor.run {
                    transcription = result.transcription
                    translation = result.translation
                    currentSampleId = result.sampleId
                    sentRating = nil
                    resultDirection = result.direction
                    autoDetectedFlip = flipped
                    lastInput = (result.transcription, .voice)
                    if flipped { Analytics.logEvent("auto_detect_flip", parameters: ["input_mode": "voice"]) }
                    statusMessage = "✅ Completed using \(result.provider)"
                    isProcessing = false
                    historyManager.addEntry(source: result.transcription, translated: result.translation, direction: result.direction)
                    logTranslationCompleted(inputMode: "voice", charLength: result.transcription.count)
                    maybeRequestReview()
                    interstitialAd.translationCompleted(isSpeaking: ttsManager.isSpeaking)
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
                    currentSampleId = nil
                    resultDirection = nil
                    autoDetectedFlip = false
                    logTranslationFailed(inputMode: "voice", error: error)
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
    // 👍/👎 for the translation; shown only when the proxy gave us a sampleId.
    var feedbackSampleId: String? = nil
    var sentRating: String? = nil
    var onFeedback: ((String) -> Void)? = nil

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
                    .disabled(content.contains("Your translation") || content == "Waiting..." || content == "Processing..." || content.isEmpty)
                }
            }

            Text(content)
                .font(.body)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .opacity(isLoading && content == "Processing..." ? 0.6 : 1.0)

            if feedbackSampleId != nil, let onFeedback = onFeedback {
                HStack(spacing: 10) {
                    Text(sentRating == nil ? "Was this right?" : "Thanks for the feedback")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    ForEach(["up", "down"], id: \.self) { rating in
                        Button(action: { onFeedback(rating) }) {
                            Image(systemName: (rating == "up" ? "hand.thumbsup" : "hand.thumbsdown")
                                  + (sentRating == rating ? ".fill" : ""))
                                .font(.title3)
                                .foregroundColor(sentRating == nil || sentRating == rating ? .accentColor : .secondary)
                                .padding(8)
                                .background(Color(UIColor.secondarySystemBackground))
                                .cornerRadius(8)
                        }
                        .disabled(sentRating != nil)
                        .accessibilityLabel(rating == "up" ? "Translation was good" : "Translation was wrong")
                    }
                }
                .padding(.top, 4)
            }
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
