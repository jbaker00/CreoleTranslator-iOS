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

    /// The conversation on screen, oldest first. Kept for this session only;
    /// History holds the lasting copy.
    @State private var turns: [ConversationTurn] = []
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
    /// What produced the newest bubble, so it can be translated again.
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

    /// A phone set to Spanish, or to a Spanish-speaking country, opens on
    /// Kreyòl + Español; everyone else opens on Kreyòl + English, which is what English- and French-language phones
    /// mostly use (65% and 62% of translations, GA4 Sept–Nov 2026). With one
    /// mic for both languages this only decides the pair, and which way to
    /// translate words the detector can't place.
    static var firstLaunchDirection: TranslationDirection {
        Language.phoneSuggestsSpanish ? .spanishToCreole : .creoleToEnglish
    }

    /// Other language the last input looked like (English typed into the
    /// Spanish pair, or the reverse). Offered as a chip; never applied silently.
    @State private var suggestedPartner: Language? = nil
    /// Version whose "what's new" card has been dismissed. The card is shown
    /// once on the first screen, and goes away on "Got it" or the first translation.
    @AppStorage("whatsNewSeenVersion") private var whatsNewSeenVersion = ""
    private static let whatsNewVersion = "3.7"

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

            Group {
            if showHistory || showPhrasebook {
                ScrollView {
                    VStack(spacing: 20) {
                        if showHistory {
                            HistoryView(historyManager: historyManager)
                                .padding(.horizontal, 20)
                                .transition(.move(edge: .trailing).combined(with: .opacity))
                        } else {
                            PhrasebookView()
                                .padding(.horizontal, 20)
                                .transition(.move(edge: .trailing).combined(with: .opacity))
                        }
                        // leave room for the banner (adaptive height, usually taller than 50)
                        Spacer(minLength: BannerAdView.size(forWidth: availableWidth).size.height + 30)
                    }
                }
                .dismissKeyboardOnScroll()
            } else {
                conversationScreen
                    .transition(.move(edge: .leading).combined(with: .opacity))
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

    // MARK: - Just talk
    //
    // No direction setting. One mic takes either language of the pair; the
    // app reads which one it got from the words and translates to the other.
    // Each sentence becomes a bubble: Kreyòl on the left, the other language
    // on the right.

    private var partner: Language { translationDirection.partner }
    private var isRecording: Bool { audioRecorder.isRecording || ScreenshotMode.showsRecording }
    private var canTranslate: Bool { !isProcessing && privacyConsent.hasConsented }
    /// Before the first sentence the mic owns the screen.
    private var showsHero: Bool { turns.isEmpty && inputMode == .voice }
    private var bannerHeight: CGFloat {
        ScreenshotMode.isActive ? 0 : BannerAdView.size(forWidth: availableWidth).size.height
    }

    private var speakPrompt: (kreyol: String, other: String) {
        if isProcessing {
            return ("N ap tradui…", UIText.pair(partner, "Translating…", "Traduciendo…"))
        }
        if isRecording {
            return ("M ap koute…", UIText.pair(partner, "Listening. Tap to stop", "Escuchando. Toca para parar"))
        }
        return ("Pale kreyòl oswa \(UIText.kreyolName(partner).lowercased())",
                UIText.pair(partner, "Speak Kreyòl or English", "Habla kreyòl o español"))
    }

    private var conversationScreen: some View {
        VStack(spacing: 0) {
            if showsHero {
                heroScreen
            } else {
                ScrollViewReader { scroller in
                    ScrollView {
                        VStack(spacing: 14) {
                            pairChip
                                .padding(.top, 8)
                            ForEach(turns) { bubble($0) }
                            if isProcessing {
                                HStack(spacing: 10) {
                                    ProgressView().tint(.secondaryText)
                                    Text("\(speakPrompt.kreyol) · \(speakPrompt.other)")
                                        .font(.subheadline)
                                        .foregroundColor(.secondaryText)
                                }
                                .frame(minHeight: 44)
                            }
                            notices
                            Color.clear.frame(height: 4).id("conversationEnd")
                        }
                        .padding(.horizontal, 16)
                    }
                    .dismissKeyboardOnScroll()
                    // The newest bubble is always brought into view, and stays
                    // in view when the keyboard opens.
                    .onChangeCompat(of: turns.count) { _ in scrollToEnd(scroller, after: 0.25) }
                    .onChangeCompat(of: isProcessing) { _ in scrollToEnd(scroller, after: 0.1) }
                    .onChangeCompat(of: inputFocused) { focused in if focused { scrollToEnd(scroller, after: 0.45) } }
                    .onAppear { scrollToEnd(scroller, after: 0.3) }
                }
                dock
            }
        }
        .padding(.bottom, bannerHeight)
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
        .onChangeCompat(of: ttsManager.isSpeaking) { speaking in
            if !speaking { speakingCardTitle = nil }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            hdCredits.refresh()
        }
    }

    private func scrollToEnd(_ scroller: ScrollViewProxy, after delay: Double) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            withAnimation { scroller.scrollTo("conversationEnd", anchor: .bottom) }
        }
    }

    /// First screen: one mic and one sentence saying what to do, in both languages.
    private var heroScreen: some View {
        GeometryReader { geo in
            ScrollView {
                VStack(spacing: 0) {
                    pairChip
                        .padding(.top, 8)
                    notices
                        .padding(.top, 12)
                    if whatsNewSeenVersion != Self.whatsNewVersion, !isRecording, !isProcessing, !ScreenshotMode.isActive {
                        whatsNewCard
                            .padding(.top, 12)
                    }
                    Spacer(minLength: 16)
                    micButton(size: 132)
                    Text(speakPrompt.kreyol)
                        .font(.title2.weight(.semibold))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 22)
                    Text(speakPrompt.other)
                        .font(.body)
                        .foregroundColor(.secondaryText)
                        .multilineTextAlignment(.center)
                        .padding(.top, 2)
                    if isRecording {
                        RecordingProgressView(elapsed: ScreenshotMode.showsRecording ? 4 : audioRecorder.elapsed)
                            .padding(.top, 18)
                    }
                    Spacer(minLength: 16)
                    Button(action: { inputMode = .text; inputFocused = true }) {
                        Label("Ekri · " + UIText.pair(partner, "Type instead", "Escribir"), systemImage: "keyboard")
                            .font(.body.weight(.semibold))
                            .foregroundColor(.appAccent)
                            .frame(maxWidth: .infinity, minHeight: 50)
                    }
                    .buttonStyle(.plain)
                    .disabled(isProcessing || isRecording)
                    .opacity(isRecording ? 0 : 1)
                    .padding(.bottom, 8)
                }
                .padding(.horizontal, 16)
                .frame(minHeight: geo.size.height)
            }
        }
    }

    /// What changed in this version, said once: one mic for both languages,
    /// and Spanish. Each line is in the interface language and in Kreyòl.
    private var whatsNewCard: some View {
        func line(_ symbol: String, _ text: String, _ kreyol: String) -> some View {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: symbol)
                    .font(.body.weight(.semibold))
                    .foregroundColor(.appAccent)
                    .frame(width: 26)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 1) {
                    Text(text)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.primary)
                    Text(kreyol)
                        .font(.subheadline)
                        .foregroundColor(.secondaryText)
                }
                .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .accessibilityElement(children: .combine)
        }
        return VStack(alignment: .leading, spacing: 10) {
            Text(UIText.t("New", "Nuevo") + " · Nouvo")
                .font(.headline)
                .foregroundColor(.primary)
                .accessibilityAddTraits(.isHeader)
            line("mic.fill",
                 UIText.t("One button for both languages. Just speak.", "Un solo botón para los dos idiomas. Solo habla."),
                 "Yon sèl bouton pou de lang yo. Annik pale.")
            line("globe.americas.fill",
                 UIText.t("Now in Spanish too. Tap the languages at the top.", "Ahora también en español. Toca los idiomas arriba."),
                 "Kounye a an panyòl tou. Peze lang yo anlè a.")
            Button(action: { whatsNewSeenVersion = Self.whatsNewVersion }) {
                Text(UIText.t("Got it", "Entendido") + " · Dakò")
                    .font(.body.weight(.semibold))
                    .foregroundColor(.appAccent)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.top, 14)
        .padding(.bottom, 4)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.controlSurface))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.controlBorder, lineWidth: 1.5))
    }

    /// Kreyòl is always one side, so the only choice is the other language.
    private var pairChip: some View {
        Menu {
            ForEach([Language.english, .spanish], id: \.self) { language in
                Button(action: { choosePartner(language) }) {
                    if language == partner {
                        Label("\(language.nativeName) · \(UIText.kreyolName(language))", systemImage: "checkmark")
                    } else {
                        Text("\(language.nativeName) · \(UIText.kreyolName(language))")
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Text("\(Language.creole.flag) \(Language.creole.nativeName) + \(partner.flag) \(partner.nativeName)")
                Image(systemName: "chevron.down")
                    .font(.footnote.weight(.bold))
            }
            .font(.subheadline.weight(.semibold))
            .foregroundColor(.primary)
            .padding(.horizontal, 16)
            .frame(minHeight: 44)
            .background(Capsule().fill(Color.controlSurface))
            .overlay(Capsule().stroke(Color.controlBorder, lineWidth: 1.5))
        }
        .disabled(isProcessing || isRecording)
        .accessibilityLabel(UIText.pair(partner, "Languages: Kreyòl and \(partner.nativeName). Change the other language",
                                        "Idiomas: kreyòl y \(partner.nativeName). Cambiar el otro idioma"))
    }

    private func micButton(size: CGFloat) -> some View {
        let enabled = canTranslate || isRecording
        return Button(action: micTapped) {
            ZStack {
                if isRecording {
                    Circle().fill(Color.recordingRed.opacity(0.10)).frame(width: size * 1.36, height: size * 1.36)
                    Circle().fill(Color.recordingRed.opacity(0.18)).frame(width: size * 1.18, height: size * 1.18)
                }
                Circle().fill(enabled ? (isRecording ? Color.recordingRed : Color.accentFill) : Color.controlSurface)
                    .frame(width: size, height: size)
                Circle().stroke(Color.controlBorder, lineWidth: enabled ? 0 : 1.5)
                    .frame(width: size, height: size)
                if isProcessing {
                    ProgressView().tint(.secondaryText).scaleEffect(size > 100 ? 1.8 : 1.3)
                } else {
                    Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                        .font(.system(size: size * 0.38, weight: .semibold))
                        .foregroundColor(enabled ? .white : .secondaryText)
                }
            }
            .frame(width: size * 1.36, height: size * 1.36)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityLabel("\(speakPrompt.kreyol). \(speakPrompt.other)")
    }

    private func micTapped() {
        if audioRecorder.isRecording {
            stopRecording()
            return
        }
        Analytics.logEvent("mic_tapped", parameters: ["pair": pairCode])
        ttsManager.stop()
        startRecording()
    }

    /// Under the conversation: the mic, or the typing row.
    @ViewBuilder private var dock: some View {
        if inputMode == .voice {
            VStack(spacing: 2) {
                if isRecording {
                    RecordingProgressView(elapsed: ScreenshotMode.showsRecording ? 4 : audioRecorder.elapsed)
                }
                ZStack {
                    micButton(size: 84)
                    HStack {
                        Button(action: { inputMode = .text; inputFocused = true }) {
                            VStack(spacing: 2) {
                                Image(systemName: "keyboard")
                                    .font(.system(size: 22, weight: .medium))
                                Text("Ekri")
                                    .font(.caption.weight(.semibold))
                            }
                            .foregroundColor(.appAccent)
                            .frame(minWidth: 56, minHeight: 56)
                        }
                        .buttonStyle(.plain)
                        .disabled(isProcessing || isRecording)
                        .opacity(isRecording ? 0 : 1)
                        .accessibilityLabel(UIText.pair(partner, "Type instead", "Escribir"))
                        Spacer()
                    }
                }
                Text(isRecording || isProcessing ? "\(speakPrompt.kreyol) · \(speakPrompt.other)" : speakPrompt.kreyol)
                    .font(.footnote)
                    .foregroundColor(.secondaryText)
                    .multilineTextAlignment(.center)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 6)
        } else {
            let hasText = !typedInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            HStack(alignment: .bottom, spacing: 8) {
                Button(action: { inputFocused = false; inputMode = .voice }) {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.appAccent)
                        .frame(width: 50, height: 50)
                        .background(Circle().fill(Color.controlSurface))
                        .overlay(Circle().stroke(Color.controlBorder, lineWidth: 1.5))
                }
                .buttonStyle(.plain)
                .disabled(isProcessing)
                .accessibilityLabel(UIText.pair(partner, "Speak instead", "Hablar"))

                TextEditor(text: $typedInput)
                    .focused($inputFocused)
                    .frame(height: typeSize.isAccessibilitySize ? 120 : 76)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.controlSurface)
                    .cornerRadius(16)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.controlBorder, lineWidth: 1.5))
                    .overlay(alignment: .topLeading) {
                        if typedInput.isEmpty {
                            Text("Ekri kreyòl oswa \(UIText.kreyolName(partner).lowercased())…\n"
                                 + UIText.pair(partner, "Type Kreyòl or English…", "Escribe kreyòl o español…"))
                                .foregroundColor(.secondaryText)
                                .padding(.top, 10)
                                .padding(.leading, 13)
                                .allowsHitTesting(false)
                        }
                    }
                    .disabled(isProcessing || !privacyConsent.hasConsented)

                Button(action: submitTypedText) {
                    ZStack {
                        Circle().fill(hasText && canTranslate ? Color.accentFill : Color.controlSurface)
                        Circle().stroke(Color.controlBorder, lineWidth: hasText && canTranslate ? 0 : 1.5)
                        if isProcessing {
                            ProgressView().tint(.secondaryText)
                        } else {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(hasText && canTranslate ? .white : .secondaryText)
                        }
                    }
                    .frame(width: 50, height: 50)
                }
                .buttonStyle(.plain)
                .disabled(!hasText || !canTranslate)
                .accessibilityLabel("Tradui · " + UIText.pair(partner, "Translate", "Traducir"))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }

    /// One sentence and its translation. What was said is on top; the
    /// translation is the larger line, and Listen plays the translation.
    private func bubble(_ turn: ConversationTurn) -> some View {
        let fromCreole = turn.direction.source == .creole
        let latest = turn.id == turns.last?.id
        let card = turn.id.uuidString
        let speaking = ttsManager.isSpeaking && speakingCardTitle == card
        let target = turn.direction.target

        let listen = Button(action: { playCard(card, text: turn.translation, language: target.speechLocale) }) {
            HStack(spacing: 6) {
                Image(systemName: speaking ? "stop.fill" : "speaker.wave.2.fill")
                Text(UIText.listen(target))
            }
            .font(.body.weight(.semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .frame(minHeight: 44)
            .background(Capsule().fill(Color.accentFill))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(UIText.listen(target)), \(target.nativeName)")

        return VStack(alignment: fromCreole ? .leading : .trailing, spacing: 8) {
            VStack(alignment: .leading, spacing: 6) {
                Text("\(turn.direction.source.flag) \(turn.direction.source.nativeName)")
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(fromCreole ? .secondaryText : .white)
                Text(turn.source)
                    .font(.body)
                    .foregroundColor(fromCreole ? .primary : .white)
                Rectangle()
                    .fill(fromCreole ? Color.controlBorder.opacity(0.4) : Color.white.opacity(0.4))
                    .frame(height: 1)
                    .accessibilityHidden(true)
                Text(turn.translation)
                    .font(.title3.weight(.semibold))
                    .foregroundColor(fromCreole ? .appAccent : .white)
            }
            .textSelection(.enabled)
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 20).fill(fromCreole ? Color.controlSurface : Color.accentFill))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.controlBorder, lineWidth: fromCreole ? 1.5 : 0))
            .padding(fromCreole ? .trailing : .leading, 32)
            .accessibilityElement(children: .combine)

            if latest {
                // Only the newest bubble carries the extras; older ones keep Listen.
                let extras = HStack(spacing: 8) {
                    if turn.sampleId != nil, turn.sampleId == currentSampleId {
                        ForEach(["up", "down"], id: \.self) { rating in
                            Button(action: { rate(rating) }) {
                                Image(systemName: (rating == "up" ? "hand.thumbsup" : "hand.thumbsdown")
                                      + (sentRating == rating ? ".fill" : ""))
                                    .font(.body.weight(.medium))
                                    .foregroundColor(sentRating == nil || sentRating == rating ? .appAccent : .secondaryText)
                                    .frame(width: 44, height: 44)
                                    .background(Circle().fill(Color.controlSurface))
                                    .overlay(Circle().stroke(Color.controlBorder, lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                            .disabled(sentRating != nil)
                            .accessibilityLabel(rating == "up" ? "Translation was good" : "Translation was wrong")
                        }
                    }
                    Button(action: translateLastOtherWay) {
                        Image(systemName: "arrow.left.arrow.right")
                            .font(.body.weight(.medium))
                            .foregroundColor(.appAccent)
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(Color.controlSurface))
                            .overlay(Circle().stroke(Color.controlBorder, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .disabled(isProcessing)
                    .accessibilityLabel(UIText.pair(partner, "Wrong language? Translate the other way",
                                                    "¿Idioma equivocado? Traducir al revés"))
                }
                let hd = Group {
                    if voiceSettings.usesHDVoice(target) {
                        HDPlaysChip(playsLeft: hdCredits.playsLeft, action: hdChipTapped)
                            // Solid surface behind the tint: on the gray body the chip text was 4.2:1.
                            .background(Capsule().fill(Color.controlSurface))
                    }
                }
                if typeSize.isAccessibilitySize {
                    VStack(alignment: fromCreole ? .leading : .trailing, spacing: 8) {
                        HStack(spacing: 8) { listen; hd }
                        extras
                    }
                } else {
                    // Listen sits under its own bubble's side.
                    if fromCreole {
                        HStack(spacing: 8) { listen; hd; Spacer(minLength: 4); extras }
                    } else {
                        HStack(spacing: 8) { extras; Spacer(minLength: 4); hd; listen }
                    }
                }
            } else {
                listen
            }
        }
        .frame(maxWidth: .infinity, alignment: fromCreole ? .leading : .trailing)
    }

    private func rate(_ rating: String) {
        guard let id = currentSampleId, sentRating == nil else { return }
        sentRating = rating
        Analytics.logEvent("translation_feedback", parameters: ["rating": rating])
        Task { await GroqService().sendFeedback(sampleId: id, rating: rating) }
    }

    /// Things that are not part of the conversation: a wrong-pair offer,
    /// short status lines, and errors.
    @ViewBuilder private var notices: some View {
        // Wrong pair (Spanish said into the English pair): offer it, don't assume it.
        if let other = suggestedPartner, !isProcessing {
            HStack(spacing: 8) {
                Image(systemName: "globe")
                Text(UIText.t("That looked like \(other.nativeName).", "Eso parecía \(other.nativeName)."))
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 4)
                Button(UIText.t("Switch to \(other.nativeName)", "Cambiar a \(other.nativeName)")) { acceptSuggestedPartner() }
                    .font(.subheadline.bold())
                    .frame(minHeight: 44)
            }
            .padding(.leading, 12)
            .padding(.trailing, 10)
            .foregroundColor(.appAccent)
            .background(Color.controlSurface)
            .cornerRadius(14)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.appAccent, lineWidth: 1.5))
        }

        if !statusMessage.isEmpty {
            Text(statusMessage)
                .font(.subheadline)
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
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
        }

        if let error = errorMessage {
            Text(error)
                .font(.subheadline)
                .foregroundColor(.errorText)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.controlSurface)
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.controlBorder, lineWidth: 1))
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
        if UserDefaults.standard.string(forKey: "shotInput") == "settings" { showSettings = true }
        if ScreenshotMode.phrasebookCategory != nil {
            showPhrasebook = true
        } else if ScreenshotMode.scene == "talk" {
            // A two-turn conversation, one bubble from each side.
            turns = [
                ConversationTurn(source: "Kote lopital la ye?", translation: "Where is the hospital?",
                                 direction: .creoleToEnglish, sampleId: nil, input: .voice),
                ConversationTurn(source: "Turn left at the corner.", translation: "Vire agoch nan kwen an.",
                                 direction: .englishToCreole, sampleId: nil, input: .voice),
            ]
            translationDirection = .englishToCreole
        } else if ScreenshotMode.scene == "talk-es" {
            turns = [
                ConversationTurn(source: "Kote lopital la ye?", translation: "¿Dónde está el hospital?",
                                 direction: .creoleToSpanish, sampleId: nil, input: .voice),
                ConversationTurn(source: "Doble a la izquierda en la esquina.", translation: "Vire agoch nan kwen an.",
                                 direction: .spanishToCreole, sampleId: nil, input: .voice),
            ]
            translationDirection = .spanishToCreole
        } else if let (source, translated, direction) = ScreenshotMode.sampleResult {
            translationDirection = direction
            turns = [ConversationTurn(source: source, translation: translated, direction: direction, sampleId: nil, input: .voice)]
        }
        statusMessage = ""
        if let typed = UserDefaults.standard.string(forKey: "shotTyped") { typedInput = typed }
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
                statusMessage = ""
                processAudio(url: url)
            }
            audioRecorder.startRecording { url in
                recordingURL = url
                statusMessage = ""
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
        statusMessage = ""
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
        // Earlier bubbles keep the languages they were translated in.
        translationDirection = translationDirection.with(partner: partner)
        suggestedPartner = nil
        Analytics.logEvent("pair_selected", parameters: ["pair": pairCode])
    }

    private func acceptSuggestedPartner() {
        guard let partner = suggestedPartner, let input = lastInput else { return }
        suggestedPartner = nil
        translationDirection = TranslationDirection(source: partner, target: .creole) ?? translationDirection
        Analytics.logEvent("pair_suggestion_accepted", parameters: ["pair": pairCode])
        processTextInput(input.text, source: input.source, replaceLast: true)
    }

    /// "en-ht" or "es-ht", whichever way the user is facing.
    private var pairCode: String { "\(translationDirection.partner.code)-ht"
    }

    /// The way out when the app read the language wrong: the newest bubble is
    /// translated again in the opposite direction, with detection off.
    private func translateLastOtherWay() {
        guard let last = turns.last,
              let reversed = TranslationDirection(source: last.direction.target, target: last.direction.source) else { return }
        Analytics.logEvent("auto_detect_undo", parameters: ["direction": directionCode])
        processTextInput(last.source, source: last.input, forced: reversed, replaceLast: true)
    }

    /// Adds a finished translation to the conversation. The direction it used
    /// is remembered as the fallback for words the detector can't place.
    private func show(_ result: TranslationResult, input: TranslationSource, replaceLast: Bool) {
        let turn = ConversationTurn(source: result.transcription, translation: result.translation,
                                    direction: result.direction, sampleId: result.sampleId, input: input)
        if replaceLast, !turns.isEmpty { turns.removeLast() }
        turns.append(turn)
        translationDirection = result.direction
        whatsNewSeenVersion = Self.whatsNewVersion
        currentSampleId = result.sampleId
        sentRating = nil
        lastInput = (result.transcription, input)
        suggestedPartner = Self.otherPartner(for: result.transcription, selected: result.direction)
        statusMessage = ""
        isProcessing = false
        historyManager.addEntry(source: result.transcription, translated: result.translation, direction: result.direction)
        maybeRequestReview()
        interstitialAd.translationCompleted(isSpeaking: ttsManager.isSpeaking)
    }

    /// `forced` skips detection (used by "translate the other way").
    private func processTextInput(_ text: String, source: TranslationSource = .typed,
                                  forced: TranslationDirection? = nil, replaceLast: Bool = false) {
        isProcessing = true
        errorMessage = nil
        let fallback = translationDirection
        let direction = forced ?? Self.detectedDirection(for: text, manual: fallback, autoDetectEnabled: true)

        Task {
            do {
                let groqService = GroqService()
                let result = try await groqService.processText(text, direction: direction, source: source, autoDirection: forced == nil)

                await MainActor.run {
                    show(result, input: source, replaceLast: replaceLast)
                    if source == .typed, !replaceLast { typedInput = "" }
                    logTranslationCompleted(inputMode: source == .voice ? "voice" : "text", charLength: text.count)
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Error: \(error.localizedDescription)"
                    statusMessage = ""
                    isProcessing = false
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
        errorMessage = nil

        Task {
            do {
                let groqService = GroqService()
                let fallback = translationDirection
                // Always transcribed by the Creole engine: it writes down
                // whichever language was actually spoken (checked with English,
                // Spanish and Kreyòl clips), so the words can decide the direction.
                let result = try await groqService.processAudio(fileURL: url, direction: fallback,
                                                                transcribeAs: Language.creole.code,
                                                                autoDirection: true) { transcript in
                    Self.detectedDirection(for: transcript, manual: fallback, autoDetectEnabled: true)
                }

                await MainActor.run {
                    show(result, input: .voice, replaceLast: false)
                    UIAccessibility.post(notification: .announcement,
                                         argument: "\(result.direction.target.nativeName): \(result.translation)")
                    logTranslationCompleted(inputMode: "voice", charLength: result.transcription.count)
                }

                // Clean up audio file
                audioRecorder.deleteRecording(at: url)

            } catch {
                await MainActor.run {
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
                }

                // Clean up audio file
                audioRecorder.deleteRecording(at: url)
            }
        }
    }
}

/// One spoken or typed sentence and its translation, shown as a bubble.
struct ConversationTurn: Identifiable {
    let id = UUID()
    let source: String
    let translation: String
    let direction: TranslationDirection
    let sampleId: String?
    let input: TranslationSource
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
    /// Set on the translation card only: its speaker becomes the one big,
    /// worded play button. The source card keeps a small icon, so "play what
    /// the other person needs to hear" is not a coin flip between two twins.
    var speakerLabel: String? = nil
    // HD voice plays left (nil = system voice selected, no chip).
    var hdPlaysLeft: Int? = nil
    var onHDChip: (() -> Void)? = nil
    // 👍/👎 for the translation; shown only when the proxy gave us a sampleId.
    var feedbackSampleId: String? = nil
    var sentRating: String? = nil
    var onFeedback: ((String) -> Void)? = nil
    var feedbackPrompt: String = UIText.t("Was this right?", "¿Es correcto?")
    var feedbackNoun: String = "Translation"

    @Environment(\.dynamicTypeSize) private var typeSize

    @ViewBuilder private var titleView: some View {
                if !icon.isEmpty {
                    Text(icon)
                        .font(.title2)
                }
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
    }

    @ViewBuilder private var controls: some View {
                // Show speaker button if speakerAction is provided
                if let action = speakerAction {
                    let playable = !(content.contains("Your translation") || content.contains("Your transcription") || content == "Waiting..." || content == "Processing..." || content.isEmpty)
                    if playable, let left = hdPlaysLeft, let onHDChip = onHDChip {
                        HDPlaysChip(playsLeft: left, action: onHDChip)
                    }
                    Button(action: action) {
                        if let speakerLabel {
                            HStack(spacing: 6) {
                                Image(systemName: isSpeaking ? "stop.fill" : "speaker.wave.2.fill")
                                Text(speakerLabel)
                            }
                            .font(.body.weight(.semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 14)
                            .frame(minHeight: 44)
                            .background(Color.accentFill)
                            .cornerRadius(10)
                        } else {
                            Image(systemName: isSpeaking ? "speaker.wave.3.fill" : "speaker.wave.2")
                                .font(.title3)
                                .foregroundColor(.appAccent)
                                .frame(minWidth: 44, minHeight: 44)
                        }
                    }
                    .accessibilityLabel("\(speakerLabel ?? UIText.t("Listen", "Escuchar")), \(title)")
                    .disabled(content.contains("Your translation") || content == "Waiting..." || content == "Processing..." || content.isEmpty)
                }
    }

    private var isPlaceholder: Bool {
        content.contains("Your translation") || content.contains("Your transcription") || content == "Waiting..." || content == "Processing..."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Large text sizes put the buttons on their own row instead of
            // squeezing the language name against them.
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 8) {
                    HStack { titleView }
                    HStack(spacing: 10) { controls }
                }
            } else {
                HStack {
                    titleView
                    Spacer()
                    controls
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
    /// nil = nothing chosen yet.
    let selection: Value?
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
