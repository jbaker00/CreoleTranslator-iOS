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
    @Environment(\.dynamicTypeSize) private var typeSize

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
    // Remembered between launches: most people only ever translate one way,
    // and resetting to Creole → English each launch was the top cause of
    // wrong-direction input.
    @AppStorage("translationDirection") private var translationDirection: TranslationDirection = ContentView.firstLaunchDirection
    @State private var speakingCardTitle: String? = nil
    @State private var typedInput = ""
    /// Keyboard focus for the text box. Cleared on Translate: the box is
    /// disabled while translating, and without this iOS hands focus back when
    /// it is re-enabled — the keyboard reopened over the result.
    @FocusState private var inputFocused: Bool
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
    /// Direction the user had selected before an auto-detect flip adopted
    /// the detected one; Undo goes back to it.
    @State private var preFlipDirection: TranslationDirection? = nil
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

    /// A phone set to Spanish opens on Español → Kreyòl; everyone else keeps
    /// the long-standing default. Only used until the user's choice is saved.
    static var firstLaunchDirection: TranslationDirection {
        UIText.isSpanish ? .spanishToCreole : .creoleToEnglish
    }

    /// Other language the last input looked like (English typed into the
    /// Spanish pair, or the reverse). Offered as a chip; never applied silently.
    @State private var suggestedPartner: Language? = nil

    enum InputMode {
        case voice, text
    }
    
    var body: some View {
        // ZStack allows us to overlay the banner at the bottom while content scrolls above
        ZStack(alignment: .bottom) {
            // Flat body: one palette works in both modes, and bordered
            // controls stay visible in dark mode. The brand gradient lives
            // in the header strip only.
            Color.bodyBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
            headerBar

            ScrollView {
                VStack(spacing: 20) {
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
            .dismissKeyboardOnScroll()
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
        // Belt and braces: whenever a translation starts or finishes, the keyboard stays down.
        .onChangeCompat(of: isProcessing) { _ in inputFocused = false }
        .onChangeCompat(of: audioRecorder.lastError) { error in
            guard let error else { return }
            statusMessage = ""
            errorMessage = error
        }
    }
    
    /// Plain bar: app name + History / Phrasebook / Settings.
    private var headerBar: some View {
        HStack(spacing: 2) {
            Text("Creole Translator")
                .font(.title3.weight(.bold))
                .foregroundColor(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 8)
            headerButton(showHistory ? "xmark" : "clock.arrow.circlepath", label: showHistory ? UIText.t("Close history", "Cerrar historial") : UIText.t("History", "Historial")) {
                withAnimation {
                    showPhrasebook = false
                    showHistory.toggle()
                }
                if showHistory {
                    Analytics.logEvent(AnalyticsEventScreenView, parameters: [AnalyticsParameterScreenName: "history"])
                }
            }
            headerButton(showPhrasebook ? "xmark" : "book.fill", label: showPhrasebook ? UIText.t("Close phrasebook", "Cerrar frases") : UIText.t("Phrasebook", "Frases")) {
                withAnimation {
                    showHistory = false
                    showPhrasebook.toggle()
                }
                if showPhrasebook {
                    Analytics.logEvent(AnalyticsEventScreenView, parameters: [AnalyticsParameterScreenName: "phrasebook"])
                }
            }
            headerButton("gearshape", label: UIText.t("Settings", "Configuración")) {
                showSettings = true
                Analytics.logEvent(AnalyticsEventScreenView, parameters: [AnalyticsParameterScreenName: "settings"])
            }
        }
        .padding(.leading, 16)
        .padding(.trailing, 6)
        .padding(.vertical, 4)
        .background(Color.bodyBackground.ignoresSafeArea(edges: .top))
        .sheet(isPresented: $showSettings) {
            SettingsView(voiceSettings: voiceSettings, ttsManager: ttsManager, privacyConsent: privacyConsent)
        }
    }

    private func headerButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 21, weight: .medium))
                .foregroundColor(.primary)
                .frame(width: 44, height: 44)
        }
        .accessibilityLabel(label)
    }

    /// The two languages on screen: the chosen partner on the left, Kreyòl
    /// always on the right so its button never moves.
    private var pairLanguages: [Language] { [translationDirection.partner, .creole] }

    private func direction(speaking language: Language) -> TranslationDirection {
        let partner = translationDirection.partner
        let made = language == .creole ? TranslationDirection(source: .creole, target: partner)
                                       : TranslationDirection(source: partner, target: .creole)
        return made ?? translationDirection
    }

    /// Kreyòl is always one side, so the only choice is the other language.
    private var pairRow: some View {
        let label = Text(UIText.t("Kreyòl with:", "Kreyòl con:"))
            .font(.subheadline)
            .foregroundColor(.secondaryText)
        let picker = SegmentedChoice(options: [Language.english, .spanish].map { ($0, $0.nativeName, nil) },
                                     selection: translationDirection.partner,
                                     onSelect: choosePartner)
        return Group {
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 6) { label; picker }
            } else {
                HStack(spacing: 10) { label; picker }
            }
        }
        .accessibilityElement(children: .contain)
    }

    /// No direction setting: each person taps the mic with their own language
    /// on it, and that tap both picks the direction and starts listening.
    private var voiceInput: some View {
        VStack(spacing: 10) {
            Text(UIText.t("Tap your language to talk", "Toca tu idioma para hablar"))
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)

            if typeSize.isAccessibilitySize {
                VStack(spacing: 10) { ForEach(pairLanguages, id: \.self) { micCard($0, stacked: true) } }
            } else {
                HStack(spacing: 10) { ForEach(pairLanguages, id: \.self) { micCard($0, stacked: false) } }
            }

            if audioRecorder.isRecording {
                RecordingProgressView(elapsed: audioRecorder.elapsed)
            }

            Button(action: { inputMode = .text }) {
                Label(UIText.t("Type instead", "Escribir"), systemImage: "keyboard")
                    .font(.body.weight(.semibold))
                    .foregroundColor(.appAccent)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Color.controlSurface))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.controlBorder, lineWidth: 1.5))
            }
            .buttonStyle(.plain)
            .disabled(isProcessing || audioRecorder.isRecording)
        }
        .padding(.horizontal, 16)
    }

    private func micCard(_ language: Language, stacked: Bool) -> some View {
        let mine = translationDirection.source == language
        let recording = audioRecorder.isRecording && mine
        let translating = isProcessing && mine
        // The card not in use steps back while the other one listens or translates.
        let waiting = (audioRecorder.isRecording || isProcessing) && !mine
        let enabled = canTranslate && !waiting
        let hint = translating ? UIText.translating(language)
            : (recording ? UIText.tapToStop(language) : UIText.tapToSpeak(language))
        let name = (language == .creole ? "🇭🇹 " : "") + language.nativeName

        let circle = ZStack {
            Circle().fill(enabled ? (recording ? Color.recordingRed : Color.accentFill) : Color.controlSurface)
            Circle().stroke(Color.controlBorder, lineWidth: enabled ? 0 : 1.5)
            if translating {
                ProgressView().tint(.secondaryText).scaleEffect(1.2)
            } else {
                Image(systemName: recording ? "stop.fill" : "mic.fill")
                    .font(.system(size: 27, weight: .semibold))
                    .foregroundColor(enabled ? .white : .secondaryText)
            }
        }
        .frame(width: 64, height: 64)

        let labels = VStack(alignment: stacked ? .leading : .center, spacing: 2) {
            Text(name)
                .font(.title3.weight(.bold))
                .foregroundColor(.primary)
            Text(hint)
                .font(.subheadline)
                .foregroundColor(recording ? .errorText : .secondaryText)
        }
        .multilineTextAlignment(stacked ? .leading : .center)

        return Button(action: { micTapped(language) }) {
            Group {
                if stacked {
                    HStack(spacing: 14) { circle; labels; Spacer(minLength: 0) }
                        .padding(.horizontal, 14)
                        .frame(maxWidth: .infinity, minHeight: 84)
                } else {
                    VStack(spacing: 6) { circle; labels }
                        .padding(.horizontal, 6)
                        .frame(maxWidth: .infinity, minHeight: 132)
                }
            }
            .background(RoundedRectangle(cornerRadius: 16).fill(Color.controlSurface))
            .overlay(RoundedRectangle(cornerRadius: 16)
                .stroke(recording ? Color.recordingRed : Color.controlBorder, lineWidth: recording ? 3 : 1.5))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(waiting ? 0.45 : 1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(language.nativeName), \(hint)")
        .accessibilityAddTraits(.isButton)
    }

    private func micTapped(_ language: Language) {
        if audioRecorder.isRecording {
            stopRecording()
            return
        }
        let chosen = direction(speaking: language)
        Analytics.logEvent("mic_tapped", parameters: [
            "language": language.code,
            "pair": pairCode,
            "changed_direction": chosen != translationDirection ? "yes" : "no",
        ])
        if chosen != translationDirection {
            // The old result keeps its own labels through resultDirection.
            translationDirection = chosen
            autoDetectedFlip = false
            preFlipDirection = nil
            suggestedPartner = nil
        }
        startRecording()
    }

    /// Typing keeps the same two-way choice as the mics, so there is one
    /// model to learn: pick your language, then give the app your words.
    private var textInput: some View {
        VStack(spacing: 12) {
            SegmentedChoice(options: pairLanguages.map { ($0, UIText.typeIn($0), nil) },
                            selection: translationDirection.source,
                            onSelect: { language in
                                let chosen = direction(speaking: language)
                                guard chosen != translationDirection else { return }
                                translationDirection = chosen
                                autoDetectedFlip = false
                                preFlipDirection = nil
                                suggestedPartner = nil
                                Analytics.logEvent("direction_switched", parameters: ["direction": directionCode, "pair": pairCode])
                            })
                .disabled(isProcessing)

            let inputLabel = UIText.typeHere(translationDirection.source)
            TextEditor(text: $typedInput)
                .focused($inputFocused)
                .frame(minHeight: 100, maxHeight: 160)
                .padding(10)
                .background(Color.controlSurface)
                .cornerRadius(14)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.controlBorder, lineWidth: 1.5)
                )
                .overlay(alignment: .topLeading) {
                    if typedInput.isEmpty {
                        Text(inputLabel)
                            .foregroundColor(.secondaryText)
                            .padding(.top, 18)
                            .padding(.leading, 14)
                            .allowsHitTesting(false)
                    }
                }
                .disabled(isProcessing || !privacyConsent.hasConsented)

            let hasText = !typedInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            Button(action: { submitTypedText() }) {
                HStack(spacing: 10) {
                    if isProcessing {
                        ProgressView().tint(.secondaryText)
                    } else {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.title3)
                    }
                    Text(isProcessing ? UIText.t("Translating…", "Traduciendo…") : UIText.t("Translate", "Traducir"))
                        .font(.title3.weight(.semibold))
                }
                .frame(maxWidth: .infinity, minHeight: 56)
                .modifier(PrimaryButtonSurface(enabled: hasText && canTranslate, fill: .accentFill))
            }
            .disabled(!hasText || !canTranslate)

            Button(action: { inputFocused = false; inputMode = .voice }) {
                Label(UIText.t("Speak instead", "Hablar"), systemImage: "mic.fill")
                    .font(.body.weight(.semibold))
                    .foregroundColor(.appAccent)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Color.controlSurface))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.controlBorder, lineWidth: 1.5))
            }
            .buttonStyle(.plain)
            .disabled(isProcessing)
        }
        .padding(.horizontal, 16)
    }

    private var canTranslate: Bool { !isProcessing && privacyConsent.hasConsented }

    // Main content view extracted for cleaner code
    private var mainContentView: some View {
        VStack(spacing: 12) {
            pairRow
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .disabled(isProcessing || audioRecorder.isRecording)

            // Rescue notice sits above the input, so it is seen without
            // scrolling past the result.
            if autoDetectedFlip, let shown = resultDirection {
                HStack(spacing: 8) {
                    Image(systemName: "wand.and.stars")
                    Text(UIText.t("Auto-detected \(shown.source.nativeName) — switched for you",
                                  "Detectado: \(shown.source.nativeName). Cambiamos el idioma"))
                        .font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 4)
                    Button(UIText.t("Undo", "Deshacer")) { undoAutoDetect() }
                        .font(.subheadline.bold())
                        .frame(minWidth: 44, minHeight: 44)
                        .disabled(isProcessing)
                }
                .padding(.leading, 12)
                .padding(.trailing, 6)
                .foregroundColor(.appAccent)
                .background(Color.controlSurface)
                .cornerRadius(14)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.appAccent, lineWidth: 1.5))
                .padding(.horizontal, 16)
            }

            // Wrong pair, not just wrong direction: offer it, don't assume it.
            if let partner = suggestedPartner, !isProcessing {
                HStack(spacing: 8) {
                    Image(systemName: "globe")
                    Text(UIText.t("That looked like \(partner.nativeName).", "Eso parecía \(partner.nativeName)."))
                        .font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 4)
                    Button(UIText.t("Switch to \(partner.nativeName)", "Cambiar a \(partner.nativeName)")) { acceptSuggestedPartner() }
                        .font(.subheadline.bold())
                        .frame(minHeight: 44)
                }
                .padding(.leading, 12)
                .padding(.trailing, 10)
                .foregroundColor(.appAccent)
                .background(Color.controlSurface)
                .cornerRadius(14)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.appAccent, lineWidth: 1.5))
                .padding(.horizontal, 16)
            }

            if inputMode == .voice {
                voiceInput
            } else {
                textInput
            }

            // Status message — only for things the result cards don't already
            // show (too short, nothing heard, time's up).
            if !statusMessage.isEmpty {
                Text(statusMessage)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
            }

            // Results section
            VStack(spacing: 20) {
                // Source language card
                let shownDirection = resultDirection ?? translationDirection
                let sourceLanguage = shownDirection.source.speechLocale
                ResultCard(
                    title: shownDirection.source.nativeName,
                    icon: shownDirection.source == .creole ? "🇭🇹" : "",
                    content: transcription,
                    isLoading: isProcessing,
                    speakerAction: { playCard("source", text: transcription, language: sourceLanguage) },
                    isSpeaking: ttsManager.isSpeaking && speakingCardTitle == "source",
                    hdPlaysLeft: voiceSettings.usesHDVoice(shownDirection.source) ? hdCredits.playsLeft : nil,
                    onHDChip: hdChipTapped,
                    feedbackSampleId: (isProcessing || lastInput?.source != .voice) ? nil : currentSampleId,
                    sentRating: sentSttRating,
                    onFeedback: { rating in
                        guard let id = currentSampleId, sentSttRating == nil else { return }
                        sentSttRating = rating
                        Analytics.logEvent("stt_feedback", parameters: ["rating": rating])
                        Task { await GroqService().sendFeedback(sampleId: id, rating: rating, target: "stt") }
                    },
                    feedbackPrompt: UIText.t("Heard right?", "¿Te entendió bien?"),
                    feedbackNoun: "Transcription"
                )

                // Target language card
                let targetLanguage = shownDirection.target.speechLocale
                ResultCard(
                    title: shownDirection.target.nativeName,
                    icon: shownDirection.target == .creole ? "🇭🇹" : "",
                    content: translation,
                    isLoading: isProcessing,
                    speakerAction: { playCard("target", text: translation, language: targetLanguage) },
                    isSpeaking: ttsManager.isSpeaking && speakingCardTitle == "target",
                    hdPlaysLeft: voiceSettings.usesHDVoice(shownDirection.target) ? hdCredits.playsLeft : nil,
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
            .padding(.horizontal, 16)
            .padding(.top, 8)
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
                    .foregroundColor(.warningText)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.controlSurface)
                    .cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.controlBorder, lineWidth: 1))
                    .padding(.horizontal, 16)
            }

            // Error message
            if let error = errorMessage {
                Text(error)
                    .font(.subheadline)
                    .foregroundColor(.errorText)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.controlSurface)
                    .cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.controlBorder, lineWidth: 1))
                    .padding(.horizontal, 16)
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
        if UserDefaults.standard.string(forKey: "shotInput") == "text" { inputMode = .text }
        if ScreenshotMode.phrasebookCategory != nil {
            showPhrasebook = true
        } else if let (source, translated, direction) = ScreenshotMode.sampleResult {
            translationDirection = direction
            resultDirection = direction
            transcription = source
            translation = translated
            statusMessage = ""
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
            statusMessage = "🎤 Too short — tap the mic button, speak, then tap Stop."
            return
        }
        
        recordingURL = url
        statusMessage = "⏳ Processing..."
        processAudio(url: url)
    }
    
    private func submitTypedText() {
        let text = typedInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        inputFocused = false
        errorMessage = nil
        statusMessage = ""
        processTextInput(text)
    }

    /// Applies the auto-detect setting: returns the direction to translate
    /// `text` in, given the user's chosen direction.
    private static func detectedDirection(for text: String, manual: TranslationDirection, autoDetectEnabled: Bool) -> TranslationDirection {
        guard autoDetectEnabled else { return manual }
        let partner = manual.partner
        switch LanguageDetector.detect(text, partner: partner) {
        case .creole:  return TranslationDirection(source: .creole, target: partner) ?? manual
        case .english, .spanish: return TranslationDirection(source: partner, target: .creole) ?? manual
        case .unknown: return manual
        }
    }

    /// The other non-Creole language, when the text clearly reads as that one
    /// and not as anything in the selected pair.
    private static func otherPartner(for text: String, selected: TranslationDirection) -> Language? {
        let other: Language = selected.partner == .english ? .spanish : .english
        guard LanguageDetector.detect(text, partner: selected.partner) == .unknown else { return nil }
        let guess = LanguageDetector.detect(text, partner: other)
        return (guess == .english || guess == .spanish) ? other : nil
    }

    private func choosePartner(_ partner: Language) {
        guard partner != translationDirection.partner else { return }
        withAnimation {
            translationDirection = translationDirection.with(partner: partner)
            resultDirection = nil
            autoDetectedFlip = false
            preFlipDirection = nil
            suggestedPartner = nil
        }
        Analytics.logEvent("pair_selected", parameters: ["pair": pairCode])
    }

    private func acceptSuggestedPartner() {
        guard let partner = suggestedPartner, let input = lastInput else { return }
        suggestedPartner = nil
        translationDirection = TranslationDirection(source: partner, target: .creole) ?? translationDirection
        Analytics.logEvent("pair_suggestion_accepted", parameters: ["pair": pairCode])
        processTextInput(input.text, source: input.source)
    }

    /// "en-ht" or "es-ht", whichever way the user is facing.
    private var pairCode: String { "\(translationDirection.partner.code)-ht"
    }

    private func undoAutoDetect() {
        guard let input = lastInput else { return }
        if let previous = preFlipDirection { translationDirection = previous }
        Analytics.logEvent("auto_detect_undo", parameters: ["direction": directionCode])
        processTextInput(input.text, source: input.source, allowAutoDetect: false)
    }

    /// An auto-detect flip (on-device or by the proxy) adopts the detected
    /// direction, so the cards and the typing choice agree. Undo restores `manual`.
    private func applyResultDirection(_ used: TranslationDirection, manual: TranslationDirection, device: TranslationDirection, inputMode: String) {
        resultDirection = used
        autoDetectedFlip = used != manual
        preFlipDirection = autoDetectedFlip ? manual : nil
        guard autoDetectedFlip else { return }
        translationDirection = used
        UIAccessibility.post(notification: .announcement,
                             argument: UIText.t("Auto-detected \(used.source.englishName). Direction switched.",
                                                 "Detectado: \(used.source.nativeName). Dirección cambiada."))
        Analytics.logEvent("auto_detect_flip", parameters: [
            "input_mode": inputMode,
            "pair": pairCode,
            "by": device != manual ? "device" : "proxy",
        ])
    }

    private func processTextInput(_ text: String, source: TranslationSource = .typed, allowAutoDetect: Bool = true) {
        isProcessing = true
        transcription = "Processing..."
        translation = "Waiting..."
        let manual = translationDirection
        let autoDetect = allowAutoDetect && voiceSettings.autoDetectLanguage
        let direction = Self.detectedDirection(for: text, manual: manual, autoDetectEnabled: autoDetect)

        Task {
            do {
                let groqService = GroqService()
                let result = try await groqService.processText(text, direction: direction, source: source, autoDirection: autoDetect)

                await MainActor.run {
                    transcription = result.transcription
                    translation = result.translation
                    currentSampleId = result.sampleId
                    sentRating = nil
                    sentSttRating = nil
                    applyResultDirection(result.direction, manual: manual, device: direction, inputMode: source.rawValue)
                    lastInput = (text, source)
                    suggestedPartner = Self.otherPartner(for: text, selected: result.direction)
                    statusMessage = ""
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
        // English pair keeps its historical spellings (see note above).
        "\(translationDirection.source.englishName.lowercased())_to_\(translationDirection.target.englishName.lowercased())"
    }

    private func logTranslationCompleted(inputMode: String, charLength: Int) {
        Analytics.logEvent("translation_completed", parameters: [
            "direction": directionCode,
            "pair": pairCode,
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
                // Captured so analytics can tell an on-device flip from a proxy one.
                let deviceDirection = DirectionBox(manual)
                let result = try await groqService.processAudio(fileURL: url, direction: manual, autoDirection: autoDetect) { transcript in
                    let detected = Self.detectedDirection(for: transcript, manual: manual, autoDetectEnabled: autoDetect)
                    deviceDirection.value = detected
                    return detected
                }

                await MainActor.run {
                    transcription = result.transcription
                    translation = result.translation
                    currentSampleId = result.sampleId
                    sentRating = nil
                    sentSttRating = nil
                    applyResultDirection(result.direction, manual: manual, device: deviceDirection.value, inputMode: "voice")
                    lastInput = (result.transcription, .voice)
                    suggestedPartner = Self.otherPartner(for: result.transcription, selected: result.direction)
                    statusMessage = ""
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

private final class DirectionBox: @unchecked Sendable {
    var value: TranslationDirection
    init(_ value: TranslationDirection) { self.value = value }
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
                .tint(isLong ? Color.warningText : Color.errorText)
                .animation(.linear(duration: 0.1), value: elapsed)
            HStack {
                Text(isLong ? "Shorter phrases translate best" : "Speak one or two sentences")
                Spacer()
                Text("\(remaining)s left")
                    .monospacedDigit()
            }
            .font(.caption)
            .foregroundColor(isLong ? .warningText : .secondaryText)
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
    var feedbackPrompt: String = UIText.t("Was this right?", "¿Es correcto?")
    var feedbackNoun: String = "Translation"

    private var isPlaceholder: Bool {
        content.contains("Your translation") || content.contains("Your transcription") || content == "Waiting..." || content == "Processing..."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                if !icon.isEmpty {
                    Text(icon)
                        .font(.title2)
                }
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
                            .foregroundColor(.appAccent)
                            .frame(minWidth: 44, minHeight: 44)
                            .background(Color.appAccent.opacity(0.15))
                            .cornerRadius(10)
                    }
                    .disabled(content.contains("Your translation") || content == "Waiting..." || content == "Processing..." || content.isEmpty)
                }
            }

            Text(content)
                .font(.body)
                .foregroundColor(isPlaceholder ? .secondaryText : .primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .opacity(isLoading && content == "Processing..." ? 0.6 : 1.0)

            if feedbackSampleId != nil, let onFeedback = onFeedback {
                HStack(spacing: 10) {
                    Text(sentRating == nil ? feedbackPrompt : UIText.t("Thanks for the feedback", "Gracias por tu opinión"))
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    Spacer()
                    ForEach(["up", "down"], id: \.self) { rating in
                        Button(action: { onFeedback(rating) }) {
                            Image(systemName: (rating == "up" ? "hand.thumbsup" : "hand.thumbsdown")
                                  + (sentRating == rating ? ".fill" : ""))
                                .font(.title3)
                                .foregroundColor(sentRating == nil || sentRating == rating ? .appAccent : .secondaryText)
                                .frame(minWidth: 44, minHeight: 44)
                                .background(Color.appAccent.opacity(0.15))
                                .cornerRadius(10)
                        }
                        .disabled(sentRating != nil)
                        .accessibilityLabel(rating == "up" ? "\(feedbackNoun) was good" : "\(feedbackNoun) was wrong")
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(16)
        // Use a system background for cards so they contrast correctly in both appearances
        .background(Color(UIColor.tertiarySystemBackground))
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(UIColor.separator), lineWidth: 0.5))
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
            .foregroundColor(playsLeft > 0 ? .appAccent : .black)
            .background(
                Capsule().fill(playsLeft > 0 ? Color.appAccent.opacity(0.12) : Color.orange)
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
    /// Dragging the page down puts the keyboard away (iOS 16+).
    @ViewBuilder func dismissKeyboardOnScroll() -> some View {
        if #available(iOS 16.0, *) { scrollDismissesKeyboard(.interactively) } else { self }
    }

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

// MARK: - Palette

/// Colors checked against WCAG contrast (4.5:1 text, 3:1 icons) on every
/// background they sit on, in light and dark mode. Several iOS defaults miss
/// that — .secondary on white is 3.4:1, systemYellow on light gray 1.4:1,
/// white on systemOrange 2.2:1 — so views use these instead.
extension Color {
    private static func adaptive(light: UInt32, dark: UInt32) -> Color {
        func ui(_ hex: UInt32) -> UIColor {
            UIColor(red: CGFloat((hex >> 16) & 0xFF) / 255,
                    green: CGFloat((hex >> 8) & 0xFF) / 255,
                    blue: CGFloat(hex & 0xFF) / 255,
                    alpha: 1)
        }
        return Color(UIColor { $0.userInterfaceStyle == .dark ? ui(dark) : ui(light) })
    }

    /// Replaces .secondary for captions, hints and placeholders.
    static let secondaryText = adaptive(light: 0x636366, dark: 0xAEAEB2)
    /// Background for filled buttons with white text (the dark-mode accent is too light for white).
    static let accentFill = adaptive(light: 0x0060DF, dark: 0x0A60D0)
    static let errorText = adaptive(light: 0xD70015, dark: 0xFF6961)
    static let warningText = adaptive(light: 0xB34700, dark: 0xFFB340)
    static let favoriteYellow = adaptive(light: 0x856200, dark: 0xFFD60A)
    /// Stop Recording button background; white text on it in both modes.
    static let recordingRed = adaptive(light: 0xD70015, dark: 0xD70015)
    /// Explicit rather than the AccentColor asset: iOS 26 draws its own
    /// lighter system blue for .accentColor (3.1:1 on light gray).
    static let appAccent = adaptive(light: 0x0060DF, dark: 0x64B0FF)
    /// Flat screen background behind everything except the header strip.
    static let bodyBackground = adaptive(light: 0xF2F2F7, dark: 0x000000)
    /// Fill of bordered controls (direction bar, Voice/Type, text box).
    static let controlSurface = adaptive(light: 0xFFFFFF, dark: 0x1C1C1E)
    /// 1.5 pt edge that makes a control read as a control: at least 3:1
    /// against both the body and the control surface, in both modes.
    static let controlBorder = adaptive(light: 0x6E6E73, dark: 0x7C7C80)

}

/// Two-or-more-way choice with 44 pt targets and a visible edge in both modes.
struct SegmentedChoice<Value: Hashable>: View {
    let options: [(value: Value, title: String, symbol: String?)]
    let selection: Value
    let onSelect: (Value) -> Void

    private func segment(_ option: (value: Value, title: String, symbol: String?)) -> some View {
        let selected = option.value == selection
        return Button(action: { onSelect(option.value) }) {
            HStack(spacing: 6) {
                if let symbol = option.symbol { Image(systemName: symbol) }
                Text(option.title)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .multilineTextAlignment(.center)
            }
            .font(.subheadline.weight(.semibold))
            .foregroundColor(.primary)
            .padding(.horizontal, 4)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(RoundedRectangle(cornerRadius: 11).fill(selected ? Color.appAccent.opacity(0.15) : Color.clear))
            .overlay(RoundedRectangle(cornerRadius: 11).stroke(selected ? Color.appAccent : Color.clear, lineWidth: 1.5))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    var body: some View {
        HStack(spacing: 4) {
            ForEach(options.indices, id: \.self) { segment(options[$0]) }
        }
        .padding(3)
        .background(Color.controlSurface)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.controlBorder, lineWidth: 1.5))
    }
}

/// Filled when it can be pressed; a bordered surface with grey text when it can't.
struct PrimaryButtonSurface: ViewModifier {
    let enabled: Bool
    let fill: Color

    func body(content: Content) -> some View {
        content
            .foregroundColor(enabled ? .white : .secondaryText)
            .background(RoundedRectangle(cornerRadius: 14).fill(enabled ? fill : Color.controlSurface))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.controlBorder, lineWidth: enabled ? 0 : 1.5))
    }
}
