//
//  OpenAITTSService.swift
//  CreoleTranslator
//
//  Service for OpenAI text-to-speech API, used for multilingual TTS (e.g. Haitian Creole)
//  where Groq's English-only models are not suitable.
//

import Foundation

class OpenAITTSService {
    private let apiKey: String
    private let speechURL = URL(string: "https://api.openai.com/v1/audio/speech")!

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    // Synthesize speech using OpenAI TTS (tts-1 model). Returns MP3 audio data.
    // The tts-1 model is multilingual and will speak whatever language the input text is in.
    func synthesizeSpeech(text: String, voice: String = "alloy") async throws -> Data {
        var request = URLRequest(url: speechURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload: [String: Any] = [
            "model": "tts-1",
            "input": text,
            "voice": voice,
            "response_format": "mp3"
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

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
