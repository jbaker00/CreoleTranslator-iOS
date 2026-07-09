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
}

struct ProxyTranslationResponse: Codable {
    let translation: String
}

struct TranslationResult {
    let transcription: String
    let translation: String
    let provider: String
    let direction: TranslationDirection
}

enum GroqError: LocalizedError {
    case invalidAPIKey
    case networkError(String)
    case transcriptionFailed(String)
    case translationFailed(String)
    case speechFailed(String)
    case invalidResponse

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
        }
    }
}

class GroqService {
    private static let proxyBase = "https://us-central1-jbaker-api-proxy.cloudfunctions.net/api"
    private let transcriptionURL = URL(string: "\(proxyBase)/v1/transcribe")!
    private let translateURL = URL(string: "\(proxyBase)/v1/translate")!
    private let speechURL = URL(string: "\(proxyBase)/v1/tts-groq")!

    // apiKey retained for call-site compatibility; the proxy needs no key
    init(apiKey: String? = nil) {}

    func processText(_ text: String, direction: TranslationDirection = .creoleToEnglish) async throws -> TranslationResult {
        let translation = try await translateText(text, direction: direction)
        return TranslationResult(
            transcription: text,
            translation: translation,
            provider: "Groq (LLAMA)",
            direction: direction
        )
    }

    func processAudio(fileURL: URL, direction: TranslationDirection = .creoleToEnglish) async throws -> TranslationResult {
        // Step 1: Transcribe audio using Whisper
        let transcription = try await transcribeAudio(fileURL: fileURL, language: direction.sourceLanguage)

        // Step 2: Translate using LLAMA
        let translation = try await translateText(transcription, direction: direction)

        return TranslationResult(
            transcription: transcription,
            translation: translation,
            provider: "Groq (Whisper + LLAMA)",
            direction: direction
        )
    }

    private func proxyRequest(url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(ProxyDevice.id, forHTTPHeaderField: "x-device-id")
        request.timeoutInterval = 30
        return request
    }

    private func transcribeAudio(fileURL: URL, language: String) async throws -> String {
        var request = proxyRequest(url: transcriptionURL)
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        request.setValue(language, forHTTPHeaderField: "x-language")
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
            return result.text

        } catch let error as GroqError {
            throw error
        } catch {
            throw GroqError.networkError(error.localizedDescription)
        }
    }

    private func translateText(_ text: String, direction: TranslationDirection) async throws -> String {
        var request = proxyRequest(url: translateURL)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "text": text,
            "direction": direction.proxyDirection
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
            return result.translation

        } catch let error as GroqError {
            throw error
        } catch {
            throw GroqError.networkError(error.localizedDescription)
        }
    }

    // Synthesize speech from text using Groq's Orpheus TTS model (via proxy).
    // Returns raw WAV audio data suitable for playback with AVAudioPlayer.
    func synthesizeSpeech(text: String, voice: String = "diana") async throws -> Data {
        var request = proxyRequest(url: speechURL)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "text": text,
            "voice": voice
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
