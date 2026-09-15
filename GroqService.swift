//
//  GroqService.swift
//  CreoleTranslator
//
//  Speech/translation via the api-proxy Cloud Function (Groq upstream).
//  The Groq key lives in Firebase Secret Manager; the app ships no credentials.
//

import Foundation

enum TranslationDirection: String, Codable {
    case creoleToEnglish
    case englishToCreole

    var sourceLanguage: String {
        switch self {
        case .creoleToEnglish: return "ht" // Haitian Creole
        case .englishToCreole: return "en" // English
        }
    }

    var targetLanguage: String {
        switch self {
        case .creoleToEnglish: return "English"
        case .englishToCreole: return "Haitian Creole"
        }
    }

    // Proxy direction code — the system prompt lives server-side
    var proxyDirection: String {
        switch self {
        case .creoleToEnglish: return "ht-en"
        case .englishToCreole: return "en-ht"
        }
    }
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

    func processText(_ text: String, direction: TranslationDirection = .creoleToEnglish, source: TranslationSource = .typed) async throws -> TranslationResult {
        let translated = try await translateText(text, direction: direction, source: source)
        return TranslationResult(
            transcription: text,
            translation: translated.text,
            provider: displayProvider(translated.provider),
            direction: direction,
            sampleId: translated.sampleId
        )
    }

    /// `resolveDirection` sees the transcript before translation so the caller
    /// can apply language auto-detect; it returns the direction to translate in.
    /// Transcription itself always uses the caller's direction as Whisper's
    /// language hint — that's the only signal available before any text exists.
    func processAudio(fileURL: URL,
                      direction: TranslationDirection = .creoleToEnglish,
                      resolveDirection: ((String) -> TranslationDirection)? = nil) async throws -> TranslationResult {
        // Step 1: Transcribe audio (gpt-transcribe for Creole, Whisper for English — see creoleSttEngine)
        let (transcription, transcribeProvider) = try await transcribeAudio(fileURL: fileURL, language: direction.sourceLanguage)
        // gpt-transcribe declines rather than guesses; the proxy rejects empty text.
        if transcription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw GroqError.nothingHeard
        }

        // Step 2: Translate — in the detected direction if the caller asks
        let direction = resolveDirection?(transcription) ?? direction
        let translated = try await translateText(transcription, direction: direction, source: .voice)

        // If either leg used its fallback, surface that — it's the more useful signal.
        // (Engine-agnostic: the proxy tags every backup engine with "-fallback".)
        let provider = transcribeProvider?.hasSuffix("-fallback") == true ? transcribeProvider : translated.provider
        return TranslationResult(
            transcription: transcription,
            translation: translated.text,
            provider: displayProvider(provider),
            direction: direction,
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

    private func translateText(_ text: String, direction: TranslationDirection, source: TranslationSource) async throws -> (text: String, provider: String?, sampleId: String?) {
        var request = proxyRequest(url: translateURL)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "text": text,
            "direction": direction.proxyDirection,
            "source": source.rawValue
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
            return (result.translation, result.provider, result.sampleId)

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
