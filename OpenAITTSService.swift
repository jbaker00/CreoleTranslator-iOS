//
//  OpenAITTSService.swift
//  CreoleTranslator
//
//  Multilingual TTS (e.g. Haitian Creole) via the api-proxy Cloud Function.
//  The OpenAI key lives server-side; app binaries ship no credentials.
//

import Foundation

enum ProxyDevice {
    static var id: String {
        let key = "proxyDeviceId"
        if let existing = UserDefaults.standard.string(forKey: key) {
            return existing
        }
        let fresh = UUID().uuidString
        UserDefaults.standard.set(fresh, forKey: key)
        return fresh
    }
}

class OpenAITTSService {
    private let speechURL = URL(string: "https://us-central1-jbaker-api-proxy.cloudfunctions.net/api/v1/tts")!

    // Synthesize speech via the proxy (tts-1 server-side). Returns MP3 audio data.
    // The model is multilingual and will speak whatever language the input text is in.
    func synthesizeSpeech(text: String, voice: String = "alloy", speed: Double = 1.0) async throws -> Data {
        var request = URLRequest(url: speechURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(ProxyDevice.id, forHTTPHeaderField: "x-device-id")

        let payload: [String: Any] = [
            "text": text,
            "voice": voice,
            "speed": min(max(speed, 0.25), 2.0)
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw GroqError.invalidResponse
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
