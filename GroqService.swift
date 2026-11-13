//
//  GroqService.swift
//  CreoleTranslator
//
//  Speech/translation via the api-proxy Cloud Function (Groq upstream).
//  The Groq key lives in Firebase Secret Manager; the app ships no credentials.
//

import Foundation

/// Interface text. Spanish when the phone's first language is Spanish,
/// English otherwise — done in code because the project has no string
/// catalog yet. Strings a Creole speaker must read are written Kreyòl-first
/// at the call site (iOS has no Haitian Creole system language to follow).
/// All Spanish and Kreyòl copy here still needs a native-speaker review.
enum UIText {
    static let isSpanish: Bool = (Locale.preferredLanguages.first ?? "en").lowercased().hasPrefix("es")

    static func t(_ english: String, _ spanish: String) -> String { isSpanish ? spanish : english }

    // Mic-card and typing labels are written in the language they name, so
    // each person finds their own button without reading the other's language.
    static func tapToSpeak(_ language: Language) -> String {
        switch language {
        case .creole:  return "Peze pou pale"
        case .english: return "Tap to speak"
        case .spanish: return "Toca para hablar"
        }
    }

    static func tapToStop(_ language: Language) -> String {
        switch language {
        case .creole:  return "Peze pou sispann"
        case .english: return "Tap to stop"
        case .spanish: return "Toca para detener"
        }
    }

    static func translating(_ language: Language) -> String {
        switch language {
        case .creole:  return "N ap tradui…"
        case .english: return "Translating…"
        case .spanish: return "Traduciendo…"
        }
    }

    static func typeIn(_ language: Language) -> String {
        switch language {
        case .creole:  return "Ekri an kreyòl"
        case .english: return "Type in English"
        case .spanish: return "Escribe en español"
        }
    }

    static func tapToReply(_ language: Language) -> String {
        switch language {
        case .creole:  return "Peze pou reponn"
        case .english: return "Tap to reply"
        case .spanish: return "Toca para responder"
        }
    }

    static func listen(_ language: Language) -> String {
        switch language {
        case .creole:  return "Koute"
        case .english: return "Listen"
        case .spanish: return "Escuchar"
        }
    }

    /// What a Kreyòl speaker calls the other language ("Panyòl", not "Español").
    static func kreyolName(_ language: Language) -> String {
        switch language {
        case .creole:  return "Kreyòl"
        case .english: return "Anglè"
        case .spanish: return "Panyòl"
        }
    }

    /// Signpost text for the main screen, in the pair's other language. Shown
    /// next to its Kreyòl twin: there is no Kreyòl phone setting to key off,
    /// so Creole speakers would otherwise get every instruction in English.
    static func pair(_ partner: Language, _ english: String, _ spanish: String) -> String {
        partner == .spanish ? spanish : english
    }

    static func typeHere(_ language: Language) -> String {
        switch language {
        case .creole:  return "Ekri an kreyòl… " + t("(type Creole)", "(escribe en kreyòl)")
        case .english: return t("Type English…", "Escribe en inglés…")
        case .spanish: return t("Type Spanish… · Escribe en español…", "Escribe en español…")
        }
    }
}

/// A language the app translates. Haitian Creole is always one side of a pair.
enum Language: String, Codable, CaseIterable {
    case creole = "ht"
    case english = "en"
    case spanish = "es"

    /// Code the proxy uses (`x-language`, direction strings, TTS `language`).
    var code: String { rawValue }

    /// The language's own name for itself — what its speakers look for.
    var nativeName: String {
        switch self {
        case .creole: return "Kreyòl"
        case .english: return "English"
        case .spanish: return "Español"
        }
    }

    var englishName: String {
        switch self {
        case .creole: return "Creole"
        case .english: return "English"
        case .spanish: return "Spanish"
        }
    }

    var flag: String {
        switch self {
        case .creole: return "🇭🇹"
        case .english: return Self.regionFlag("en", among: Self.englishRegions) ?? "🇺🇸"
        case .spanish: return Self.regionFlag("es", among: Self.spanishRegions) ?? "🇲🇽"
        }
    }

    // No one flag stands for English or Spanish, so the card shows the flag
    // of the country the phone is set to when that country speaks the
    // language, and a fallback otherwise (US for English; Mexico for Spanish,
    // matching the es-MX voice and store page).
    private static let englishRegions: Set<String> = ["US", "CA", "GB", "AU", "NZ", "IE", "JM", "BS", "BB", "TT", "BZ", "GY", "ZA", "NG", "GH", "KE", "LR"]
    private static let spanishRegions: Set<String> = ["MX", "DO", "CL", "CO", "AR", "PE", "VE", "EC", "GT", "CU", "BO", "HN", "PY", "SV", "NI", "CR", "PA", "UY", "PR", "ES"]

    /// The country named in the phone's language setting wins ("Español
    /// (El Salvador)" → 🇸🇻 even on a phone whose region is the US); failing
    /// that, the phone's region.
    private static func regionFlag(_ code: String, among regions: Set<String>) -> String? {
        let fromLanguages = Locale.preferredLanguages.lazy
            .filter { $0.lowercased().hasPrefix(code + "-") }
            .compactMap { Locale(identifier: $0).regionCode?.uppercased() }
            .first { regions.contains($0) }
        let deviceRegion = Locale.current.regionCode?.uppercased()
        guard let region = fromLanguages ?? deviceRegion.flatMap({ regions.contains($0) ? $0 : nil }) else { return nil }
        return String(String.UnicodeScalarView(region.unicodeScalars.compactMap { UnicodeScalar(127397 + $0.value) }))
    }

    /// Locale for the on-device voice and for labelling speech requests.
    /// Spanish is Latin American.
    var speechLocale: String {
        switch self {
        case .creole: return "ht-HT"
        case .english: return "en-US"
        case .spanish: return "es-MX"
        }
    }

    init(speechLocale: String) {
        if speechLocale.hasPrefix("ht") { self = .creole }
        else if speechLocale.hasPrefix("es") { self = .spanish }
        else { self = .english }
    }
}

enum TranslationDirection: String, Codable {
    case creoleToEnglish
    case englishToCreole
    case creoleToSpanish
    case spanishToCreole

    var source: Language {
        switch self {
        case .creoleToEnglish, .creoleToSpanish: return .creole
        case .englishToCreole: return .english
        case .spanishToCreole: return .spanish
        }
    }

    var target: Language {
        switch self {
        case .englishToCreole, .spanishToCreole: return .creole
        case .creoleToEnglish: return .english
        case .creoleToSpanish: return .spanish
        }
    }

    /// The non-Creole language of the pair.
    var partner: Language { source == .creole ? target : source }

    var sourceLanguage: String { source.code }

    // Proxy direction code — the system prompt lives server-side
    var proxyDirection: String { "\(source.code)-\(target.code)" }

    init?(source: Language, target: Language) {
        switch (source, target) {
        case (.creole, .english): self = .creoleToEnglish
        case (.english, .creole): self = .englishToCreole
        case (.creole, .spanish): self = .creoleToSpanish
        case (.spanish, .creole): self = .spanishToCreole
        default: return nil
        }
    }

    init?(proxyDirection: String) {
        let parts = proxyDirection.split(separator: "-").map(String.init)
        guard parts.count == 2, let s = Language(rawValue: parts[0]), let t = Language(rawValue: parts[1]),
              let direction = TranslationDirection(source: s, target: t) else { return nil }
        self = direction
    }

    var reversed: TranslationDirection {
        TranslationDirection(source: target, target: source) ?? self
    }

    /// Same side of the conversation, other partner language
    /// (English → Creole becomes Spanish → Creole).
    func with(partner: Language) -> TranslationDirection {
        guard partner != .creole else { return self }
        return (source == .creole
            ? TranslationDirection(source: .creole, target: partner)
            : TranslationDirection(source: partner, target: .creole)) ?? self
    }

    /// "English to Creole" — analytics-safe, English.
    var englishTitle: String { "\(source.englishName) to \(target.englishName)" }
}

struct TranscriptionResponse: Codable {
    let text: String
    let provider: String?
    let engine: String?
}

/// Creole speech-to-text engine requested from the proxy via `x-stt-engine`.
/// "gpt-transcribe" = OpenAI gpt-transcribe primary, Groq Whisper as backup
/// (proxy ignores the header for English, which stays on Whisper). Unlike
/// Whisper, gpt-transcribe returns an empty transcript when it can't make out
/// the speech, so processAudio() turns that into `GroqError.nothingHeard`
/// rather than sending empty text to /translate. nil = proxy default (Whisper).
let creoleSttEngine: String? = "gpt-transcribe"

struct ProxyTranslationResponse: Codable {
    let translation: String
    let provider: String?
    // Set by the proxy's translation-QA capture; absent for override hits or
    // an older proxy. sampleId is what /v1/feedback rates.
    let sampleId: String?
    let confidence: Int?
    // Direction the proxy actually translated in. Differs from the request
    // only when we sent `autoDirection` and the text turned out to be in the
    // target language already. Absent on an older proxy.
    let direction: String?
}

/// Whether the text sent to /v1/translate was spoken or typed. The proxy
/// records it on the captured sample so reviewers know a garbled input may
/// be a transcription error rather than a translation one.
enum TranslationSource: String {
    case voice, typed
}

// Maps the proxy's raw provider id to a short, user-facing label.
private func displayProvider(_ raw: String?) -> String {
    switch raw {
    case "groq": return "Groq"
    case "openai": return "OpenAI"
    case "openrouter": return "OpenRouter"
    case "override": return "reviewer dictionary"
    case "groq-fallback": return "Groq (backup)"
    case "openai-fallback": return "OpenAI (backup)"
    case "openrouter-fallback": return "OpenRouter (backup)"
    default: return "Groq"
    }
}

struct TranslationResult {
    let transcription: String
    let translation: String
    let provider: String
    let direction: TranslationDirection
    /// Proxy sample id for 👍/👎 feedback; nil when the proxy served an
    /// override or didn't capture.
    var sampleId: String? = nil
}

enum GroqError: LocalizedError {
    case invalidAPIKey
    case networkError(String)
    case transcriptionFailed(String)
    case translationFailed(String)
    case speechFailed(String)
    case invalidResponse
    case nothingHeard

    var errorDescription: String? {
        switch self {
        case .invalidAPIKey:
            return "Service authorization failed. Please try again later."
        case .networkError(let message):
            return "Network error: \(message)"
        case .transcriptionFailed(let message):
            return "Transcription failed: \(message)"
        case .translationFailed(let message):
            return "Translation failed: \(message)"
        case .speechFailed(let message):
            return "Speech synthesis failed: \(message)"
        case .invalidResponse:
            return "Received invalid response from server"
        case .nothingHeard:
            return "Didn't catch that — try again, a little closer to the microphone."
        }
    }
}

class GroqService {
    private static let proxyBase = "https://us-central1-jbaker-api-proxy.cloudfunctions.net/api"
    private let transcriptionURL = URL(string: "\(proxyBase)/v1/transcribe")!
    private let translateURL = URL(string: "\(proxyBase)/v1/translate")!
    private let feedbackURL = URL(string: "\(proxyBase)/v1/feedback")!
    private let speechURL = URL(string: "\(proxyBase)/v1/tts-groq")!

    // apiKey retained for call-site compatibility; the proxy needs no key
    init(apiKey: String? = nil) {}

    /// `autoDirection` lets the proxy translate the other way when the text is
    /// already in the target language; `result.direction` says which way it went.
    func processText(_ text: String, direction: TranslationDirection = .creoleToEnglish, source: TranslationSource = .typed,
                     autoDirection: Bool = false) async throws -> TranslationResult {
        let translated = try await translateText(text, direction: direction, source: source, autoDirection: autoDirection)
        return TranslationResult(
            transcription: text,
            translation: translated.text,
            provider: displayProvider(translated.provider),
            direction: translated.direction,
            sampleId: translated.sampleId
        )
    }

    /// `resolveDirection` sees the transcript before translation so the caller
    /// can apply language auto-detect; it returns the direction to translate in.
    /// Transcription itself always uses the caller's direction as Whisper's
    /// language hint unless `transcribeAs` names another: the Creole engine
    /// writes down whichever language was spoken, so one mic can take both.
    func processAudio(fileURL: URL,
                      direction: TranslationDirection = .creoleToEnglish,
                      transcribeAs: String? = nil,
                      autoDirection: Bool = false,
                      resolveDirection: ((String) -> TranslationDirection)? = nil) async throws -> TranslationResult {
        // Step 1: Transcribe audio (gpt-transcribe for Creole, Whisper for English — see creoleSttEngine)
        let (transcription, transcribeProvider) = try await transcribeAudio(fileURL: fileURL, language: transcribeAs ?? direction.sourceLanguage)
        // gpt-transcribe declines rather than guesses; the proxy rejects empty text.
        if transcription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw GroqError.nothingHeard
        }

        // Step 2: Translate — in the detected direction if the caller asks
        let direction = resolveDirection?(transcription) ?? direction
        let translated = try await translateText(transcription, direction: direction, source: .voice, autoDirection: autoDirection)

        // If either leg used its fallback, surface that — it's the more useful signal.
        // (Engine-agnostic: the proxy tags every backup engine with "-fallback".)
        let provider = transcribeProvider?.hasSuffix("-fallback") == true ? transcribeProvider : translated.provider
        return TranslationResult(
            transcription: transcription,
            translation: translated.text,
            provider: displayProvider(provider),
            direction: translated.direction,
            sampleId: translated.sampleId
        )
    }

    /// Rates a translation the proxy captured. Fire-and-forget: a failure
    /// here is never worth surfacing to the user.
    func sendFeedback(sampleId: String, rating: String, target: String = "translation") async {
        var request = proxyRequest(url: feedbackURL)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: ["sampleId": sampleId, "rating": rating, "target": target])
            let (_, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                print("feedback: HTTP \(http.statusCode)")
            }
        } catch {
            print("feedback failed: \(error.localizedDescription)")
        }
    }

    private func proxyRequest(url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(ProxyDevice.id, forHTTPHeaderField: "x-device-id")
        request.timeoutInterval = 30
        return request
    }

    private func transcribeAudio(fileURL: URL, language: String) async throws -> (text: String, provider: String?) {
        var request = proxyRequest(url: transcriptionURL)
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        request.setValue(language, forHTTPHeaderField: "x-language")
        if let engine = creoleSttEngine { request.setValue(engine, forHTTPHeaderField: "x-stt-engine") }
        request.httpBody = try Data(contentsOf: fileURL)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw GroqError.invalidResponse
            }

            if httpResponse.statusCode == 401 {
                throw GroqError.invalidAPIKey
            }

            guard httpResponse.statusCode == 200 else {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw GroqError.transcriptionFailed(errorMessage)
            }

            let result = try JSONDecoder().decode(TranscriptionResponse.self, from: data)
            return (result.text.trimmingCharacters(in: .whitespacesAndNewlines), result.provider)

        } catch let error as GroqError {
            throw error
        } catch {
            throw GroqError.networkError(error.localizedDescription)
        }
    }

    private func translateText(_ text: String, direction: TranslationDirection, source: TranslationSource,
                               autoDirection: Bool) async throws -> (text: String, provider: String?, sampleId: String?, direction: TranslationDirection) {
        var request = proxyRequest(url: translateURL)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "text": text,
            "direction": direction.proxyDirection,
            "source": source.rawValue,
            "autoDirection": autoDirection
        ])

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw GroqError.invalidResponse
            }

            if httpResponse.statusCode == 401 {
                throw GroqError.invalidAPIKey
            }

            guard httpResponse.statusCode == 200 else {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw GroqError.translationFailed(errorMessage)
            }

            let result = try JSONDecoder().decode(ProxyTranslationResponse.self, from: data)
            let used = result.direction.flatMap(TranslationDirection.init(proxyDirection:)) ?? direction
            return (result.translation, result.provider, result.sampleId, used)

        } catch let error as GroqError {
            throw error
        } catch {
            throw GroqError.networkError(error.localizedDescription)
        }
    }

    // Synthesize speech from text using Groq's Orpheus TTS model (via proxy).
    // Returns raw WAV audio data suitable for playback with AVAudioPlayer.
    func synthesizeSpeech(text: String, voice: String = "diana", language: String = "en") async throws -> Data {
        var request = proxyRequest(url: speechURL)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // `language` lets the proxy apply pronunciation respellings for
        // Creole; it is ignored by today's proxy.
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "text": text,
            "voice": voice,
            "language": language
        ])

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw GroqError.invalidResponse
            }

            if httpResponse.statusCode == 401 {
                throw GroqError.invalidAPIKey
            }

            guard httpResponse.statusCode == 200 else {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw GroqError.speechFailed(errorMessage)
            }

            return data

        } catch let error as GroqError {
            throw error
        } catch {
            throw GroqError.networkError(error.localizedDescription)
        }
    }
}
