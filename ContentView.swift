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
    @StateObject private var rewardedAd = RewardedAdManager()
    @ObservedObject private var hdCredits = HDVoiceCredits.shared
    @Environment(\.colorScheme) private var colorScheme

    // Use the centralized Secrets helper to load the API key.

    @State private var transcription = "Your transcription will appear here..."
    @State private var translation = "Your translation will appear here..."
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var recordingURL: URL?
    @State private var statusMessage = ""
    @State private var permissionGranted = false
    @State private var availableWidth: CGFloat = UIScreen.main.bounds.width
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
    @State private var sentSttRating: String? = nil
    /// Direction the current result was actually translated in (differs
    /// from translationDirection after an auto-detect flip). nil = no result.
    @State private var resultDirection: TranslationDirection? = nil
    @State private var autoDetectedFlip = false
    /// What produced the current result, so Undo can redo it manually.
    @State private var lastInput: (text: String, source: TranslationSource)? = nil
    /// Card tapped while out of HD plays; played after the ad (or with the basic voice).
    @State private var pendingPlay: (card: String, text: String, language: String)? = nil
    @State private var showOutOfHDPrompt = false
    @State private var showHDInfo = false
    @State private var showHDGranted = false
    @State private var showNoVideo = false
    @State private var isWatchingAd = false
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

                                Text("AI voice translation")
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

                    // leave room for the banner (adaptive height, usually taller than 50)
                    Spacer(minLength: BannerAdView.size(forWidth: availableWidth).size.height + 30)
                }
            }
            .onAppear {
                if ScreenshotMode.isActive {
                    applyScreenshotScene()
                    return
                }
                // Returning users never see the consent sheet, so ask ATT
                // here; first-run users get it after the sheet (see below).
                // Resolving ATT early keeps banner requests personalized.
                if privacyConsent.hasConsented {
                    ATTAuthorization.requestIfNeeded()
                }
            }

            // Host the banner in a GeometryReader so the adaptive size tracks the current width.
            let bannerSize = BannerAdView.size(forWidth: availableWidth)
            if !ScreenshotMode.isActive {
            GeometryReader { geo in
                BannerAdView(adSize: bannerSize)
                    .frame(width: geo.size.width, height: bannerSize.size.height, alignment: .center)
                    .background(Color(UIColor.tertiarySystemBackground)) // Use system background color for consistent contrast
                    .overlay(alignment: .top) { Divider() } // Subtle divider to delineate content and ad area
                    .ignoresSafeArea(edges: .bottom) // Allow the banner to extend to the bottom edge safely
                    .onAppear { availableWidth = geo.size.width } // Initialize width on first layout
                    .onChangeCompat(of: geo.size.width) { newWidth in availableWidth = newWidth } // Update width as the device rotates or layout changes
            }
            .frame(height: bannerSize.size.height, alignment: .bottom) // Constrain the GeometryReader's height so it doesn't take over the layout
            }

        }
        .sheet(isPresented: Binding(
            get: { privacyConsent.shouldShowConsentDialog },
            set: { _ in }
        )) {
            DataPrivacyConsentView(consentManager: privacyConsent)
        }
        .onChangeCompat(of: privacyConsent.hasConsented) { consented in
            if consented { ATTAuthorization.requestIfNeeded() }
        }
        // creoletranslator://phrasebook — used by App Store In-App Events.
        .onOpenURL { url in
            guard url.scheme == "creoletranslator" else { return }
            Analytics.logEvent("deep_link_open", parameters: ["target": url.host ?? ""])
            if url.host == "phrasebook" {
                withAnimation {
                    showHistory = false
                    showPhrasebook = true
                }
            }
        }
        .onChangeCompat(of: audioRecorder.lastError) { error in
            guard let error else { return }
            statusMessage = ""
            errorMessage = error
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

                if audioRecorder.isRecording {
                    RecordingProgressView(elapsed: audioRecorder.elapsed)
                        .padding(.horizontal, 30)
                }
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
                    speakerAction: { playCard("source", text: transcription, language: sourceLanguage) },
                    isSpeaking: ttsManager.isSpeaking && speakingCardTitle == "source",
                    hdPlaysLeft: voiceSettings.usesHDVoice(isCreole: sourceLanguage.hasPrefix("ht")) ? hdCredits.playsLeft : nil,
                    onHDChip: hdChipTapped,
                    feedbackSampleId: (isProcessing || lastInput?.source != .voice) ? nil : currentSampleId,
                    sentRating: sentSttRating,
                    onFeedback: { rating in
                        guard let id = currentSampleId, sentSttRating == nil else { return }
                        sentSttRating = rating
                        Analytics.logEvent("stt_feedback", parameters: ["rating": rating])
                        Task { await GroqService().sendFeedback(sampleId: id, rating: rating, target: "stt") }
                    },
                    feedbackPrompt: "Heard right?",
                    feedbackNoun: "Transcription"
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
                    speakerAction: { playCard("target", text: translation, language: targetLanguage) },
                    isSpeaking: ttsManager.isSpeaking && speakingCardTitle == "target",
                    hdPlaysLeft: voiceSettings.usesHDVoice(isCreole: targetLanguage.hasPrefix("ht")) ? hdCredits.playsLeft : nil,
                    onHDChip: hdChipTapped,
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
            .onChangeCompat(of: ttsManager.isSpeaking) { speaking in
                if !speaking {
                    speakingCardTitle = nil
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                hdCredits.refresh()
            }
            .confirmationDialog("Out of HD voice plays", isPresented: $showOutOfHDPrompt, titleVisibility: .visible) {
                Button("Watch Video — \(HDVoiceCredits.playsPerAd) HD Plays") { watchAdForHDPlays() }
                Button("Play Basic Voice") { playPendingWithBasicVoice() }
                Button("Not Now", role: .cancel) { pendingPlay = nil }
            } message: {
                Text("Hear it in a natural AI voice: watch one short video for \(HDVoiceCredits.playsPerAd) more plays. \(HDVoiceCredits.freePlaysPerDay) free plays come back every day.\n\nGade yon ti videyo pou \(HDVoiceCredits.playsPerAd) lòt lekti ak vwa HD.")
            }
            .alert("HD Voice", isPresented: $showHDInfo) {
                Button("Watch Video") { watchAdForHDPlays() }
                Button("OK", role: .cancel) {}
            } message: {
                Text("\(hdCredits.playsLeft) HD plays left. You get \(HDVoiceCredits.freePlaysPerDay) free every day — watch a short video anytime for \(HDVoiceCredits.playsPerAd) more.\n\nOu gen \(hdCredits.playsLeft) lekti HD ki rete. Gade yon ti videyo pou \(HDVoiceCredits.playsPerAd) lòt.")
            }
            .alert("HD Plays Added", isPresented: $showHDGranted) {
                Button("OK") {}
            } message: {
                Text("\(HDVoiceCredits.playsPerAd) more HD voice plays are ready.\n\n\(HDVoiceCredits.playsPerAd) lòt lekti HD pare.")
            }
            .alert("No Video Available", isPresented: $showNoVideo) {
                Button("OK") {}
            } message: {
                Text("We couldn't load a video. The basic voice works in the meantime — check your connection and try again for \(HDVoiceCredits.playsPerAd) HD plays.\n\nNou pa t ka chaje videyo a. Tcheke koneksyon ou epi eseye ankò.")
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
    
    // MARK: - HD voice plays

    private func playCard(_ card: String, text: String, language: String) {
        if ttsManager.isSpeaking {
            ttsManager.stop()
            speakingCardTitle = nil
            return
        }
        if hdCredits.playsLeft == 0 && ttsManager.usesHDPlay(text: text, language: language) {
            guard !isWatchingAd else { return }
            pendingPlay = (card, text, language)
            showOutOfHDPrompt = true
            Analytics.logEvent("hd_voice_out_prompt", parameters: ["language": language])
            return
        }
        speakingCardTitle = card
        ttsManager.speak(text: text, language: language)
    }

    private func hdChipTapped() {
        if hdCredits.playsLeft == 0 {
            watchAdForHDPlays()
        } else {
            showHDInfo = true
        }
    }

    private func playPendingWithBasicVoice() {
        guard let pending = pendingPlay else { return }
        pendingPlay = nil
        Analytics.logEvent("hd_voice_basic_chosen", parameters: ["language": pending.language])
        speakingCardTitle = pending.card
        ttsManager.speak(text: pending.text, language: pending.language, basicVoice: true)
    }

    /// Waits up to 3s for the ad to load. A no-fill or present failure grants
    /// the plays anyway, but only once a day (see HDVoiceCredits.noAdGrantsPerDay).
    private func watchAdForHDPlays() {
        guard !isWatchingAd else { return }
        isWatchingAd = true
        Task { @MainActor in
            // Wait for the dialog's dismiss animation — presenting the ad
            // while it is still on screen fails silently.
            try? await Task.sleep(nanoseconds: 600_000_000)
            var waitedNs: UInt64 = 0
            while !rewardedAd.isReady && waitedNs < 3_000_000_000 {
                try? await Task.sleep(nanoseconds: 250_000_000)
                waitedNs += 250_000_000
            }
            var earned = false
            let shown = rewardedAd.show(
                onReward: {
                    earned = true
                    hdCredits.grantAdReward()
                    Analytics.logEvent("hd_plays_granted", parameters: ["via": "rewarded_ad"])
                },
                onDismiss: {
                    isWatchingAd = false
                    if earned { finishHDGrant() } else { pendingPlay = nil }
                },
                onPresentFailure: { grantWithoutAd(via: "present_failed") }
            )
            if !shown {
                grantWithoutAd(via: "no_fill")
            }
        }
    }

    /// No video could be shown. The first time today counts as a reward;
    /// after that the pending phrase plays with the basic voice instead.
    private func grantWithoutAd(via: String) {
        if hdCredits.canGrantWithoutAd {
            hdCredits.recordGrantWithoutAd()
            grantHDPlays(via: via)
            return
        }
        isWatchingAd = false
        let total = hdCredits.recordBlockedGrant()
        Analytics.logEvent("hd_grant_blocked", parameters: ["via": via, "total": total])
        if let pending = pendingPlay {
            pendingPlay = nil
            speakingCardTitle = pending.card
            ttsManager.speak(text: pending.text, language: pending.language, basicVoice: true)
        }
        showNoVideo = true
    }

    private func grantHDPlays(via: String) {
        isWatchingAd = false
        hdCredits.grantAdReward()
        Analytics.logEvent("hd_plays_granted", parameters: ["via": via])
        finishHDGrant()
    }

    /// Plays the card that triggered the ad; the audio is the confirmation.
    private func finishHDGrant() {
        guard let pending = pendingPlay else {
            showHDGranted = true
            return
        }
        pendingPlay = nil
        speakingCardTitle = pending.card
        ttsManager.speak(text: pending.text, language: pending.language)
    }

    private func applyScreenshotScene() {
        if ScreenshotMode.phrasebookCategory != nil {
            showPhrasebook = true
        } else if let (source, translated, direction) = ScreenshotMode.sampleResult {
            translationDirection = direction
            resultDirection = direction
            transcription = source
            translation = translated
            statusMessage = "✅ Completed"
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
            audioRecorder.onAutoStop = { url in
                Analytics.logEvent("recording_auto_stopped", parameters: nil)
                recordingURL = url
                statusMessage = "⏳ Time's up — processing..."
                processAudio(url: url)
            }
            audioRecorder.startRecording { url in
                recordingURL = url
                statusMessage = url == nil ? "" : "🔴 Recording..."
            }
        }
    }
    
    private func stopRecording() {
        guard let url = audioRecorder.stopRecording() else {
            // Nil here almost always means a too-short tap (the recorder discards those).
            statusMessage = "🎤 Too short — tap Start, speak, then tap Stop."
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
                    sentSttRating = nil
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
                    sentSttRating = nil
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
                    sentSttRating = nil
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
                    if case GroqError.nothingHeard = error {
                        // Not a failure: the engine heard nothing it could transcribe.
                        errorMessage = nil
                        statusMessage = "🎤 \(error.localizedDescription)"
                        Analytics.logEvent("stt_nothing_heard", parameters: nil)
                    } else {
                        errorMessage = "Error: \(error.localizedDescription)"
                        statusMessage = ""
                        logTranslationFailed(inputMode: "voice", error: error)
                    }
                    isProcessing = false
                    currentSampleId = nil
                    sentSttRating = nil
                    resultDirection = nil
                    autoDetectedFlip = false
                }

                // Clean up audio file
                audioRecorder.deleteRecording(at: url)
            }
        }
    }
}

/// Fills toward AudioRecorder.maxDuration so people can see how long they have left.
/// Turns orange past warnAfter, where translation accuracy starts dropping.
struct RecordingProgressView: View {
    let elapsed: TimeInterval

    private var isLong: Bool { elapsed >= AudioRecorder.warnAfter }
    private var remaining: Int { max(0, Int((AudioRecorder.maxDuration - elapsed).rounded(.up))) }

    var body: some View {
        VStack(spacing: 6) {
            ProgressView(value: elapsed, total: AudioRecorder.maxDuration)
                .tint(isLong ? .orange : .red)
                .animation(.linear(duration: 0.1), value: elapsed)
            HStack {
                Text(isLong ? "Shorter phrases translate best" : "Speak one or two sentences")
                Spacer()
                Text("\(remaining)s left")
                    .monospacedDigit()
            }
            .font(.caption)
            .foregroundColor(isLong ? .orange : .secondary)
        }
        .padding(12)
        .background(Color(UIColor.systemBackground).opacity(0.95))
        .cornerRadius(10)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Recording, \(remaining) seconds left")
    }
}

struct ResultCard: View {
    let title: String
    let icon: String
    let content: String
    let isLoading: Bool
    var speakerAction: (() -> Void)? = nil
    var isSpeaking: Bool = false
    // HD voice plays left (nil = system voice selected, no chip).
    var hdPlaysLeft: Int? = nil
    var onHDChip: (() -> Void)? = nil
    // 👍/👎 for the translation; shown only when the proxy gave us a sampleId.
    var feedbackSampleId: String? = nil
    var sentRating: String? = nil
    var onFeedback: ((String) -> Void)? = nil
    var feedbackPrompt: String = "Was this right?"
    var feedbackNoun: String = "Translation"

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
                    let playable = !(content.contains("Your translation") || content.contains("Your transcription") || content == "Waiting..." || content == "Processing..." || content.isEmpty)
                    if playable, let left = hdPlaysLeft, let onHDChip = onHDChip {
                        HDPlaysChip(playsLeft: left, action: onHDChip)
                    }
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
                    Text(sentRating == nil ? feedbackPrompt : "Thanks for the feedback")
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
                        .accessibilityLabel(rating == "up" ? "\(feedbackNoun) was good" : "\(feedbackNoun) was wrong")
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

/// Sits beside a card's speaker button: "✨ HD 3" while plays remain, then
/// "▶ +10 HD" — a tap that offers the rewarded video.
struct HDPlaysChip: View {
    let playsLeft: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: playsLeft > 0 ? "sparkles" : "play.rectangle.fill")
                    .font(.caption2.weight(.semibold))
                Text(playsLeft > 0 ? "HD \(playsLeft)" : "+\(HDVoiceCredits.playsPerAd) HD")
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .foregroundColor(playsLeft > 0 ? .accentColor : .white)
            .background(
                Capsule().fill(playsLeft > 0 ? Color.accentColor.opacity(0.12) : Color.orange)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(playsLeft > 0
            ? "\(playsLeft) HD voice plays left"
            : "Out of HD voice plays. Watch a short video for \(HDVoiceCredits.playsPerAd) more")
    }
}

#Preview {
    ContentView()
}

// MARK: - onChange compatibility

extension View {
    /// `onChange` that takes the new value, without the iOS 17 deprecation
    /// warning while the app still supports iOS 15.
    @ViewBuilder
    func onChangeCompat<V: Equatable>(of value: V, perform: @escaping (V) -> Void) -> some View {
        if #available(iOS 17.0, *) {
            onChange(of: value) { _, newValue in perform(newValue) }
        } else {
            onChange(of: value, perform: perform)
        }
    }
}
