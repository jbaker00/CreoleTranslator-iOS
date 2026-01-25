//
//  GroqService.swift
//  CreoleTranslator
//
//  Service for interacting with Groq API (Whisper + LLAMA)
//

import Foundation

struct TranscriptionResponse: Codable {
    let text: String
}

struct ChatResponse: Codable {
    let choices: [ChatChoice]
}

struct ChatChoice: Codable {
    let message: ChatMessage
}

struct ChatMessage: Codable {
    let role: String
    let content: String
}

struct TranslationResult {
    let transcription: String
    let translation: String
    let provider: String
}

enum GroqError: LocalizedError {
    case invalidAPIKey
    case networkError(String)
    case transcriptionFailed(String)
    case translationFailed(String)
    case invalidResponse
    
    var errorDescription: String? {
        switch self {
        case .invalidAPIKey:
            return "Invalid API key. Please check your Groq API key."
        case .networkError(let message):
            return "Network error: \(message)"
        case .transcriptionFailed(let message):
            return "Transcription failed: \(message)"
        case .translationFailed(let message):
            return "Translation failed: \(message)"
        case .invalidResponse:
            return "Received invalid response from server"
        }
    }
}

class GroqService {
    private let apiKey: String
    private let transcriptionURL = URL(string: "https://api.groq.com/openai/v1/audio/transcriptions")!
    private let chatURL = URL(string: "https://api.groq.com/openai/v1/chat/completions")!
    
    init(apiKey: String) {
        self.apiKey = apiKey
    }
    
    func processAudio(fileURL: URL) async throws -> TranslationResult {
        // Step 1: Transcribe audio using Whisper
        let transcription = try await transcribeAudio(fileURL: fileURL)
        
        // Step 2: Translate Creole to English using LLAMA
        let translation = try await translateText(transcription)
        
        return TranslationResult(
            transcription: transcription,
            translation: translation,
            provider: "Groq (Whisper + LLAMA)"
        )
    }
    
    private func transcribeAudio(fileURL: URL) async throws -> String {
        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: transcriptionURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        // Read audio file data
        let audioData = try Data(contentsOf: fileURL)
        
        // Build multipart form data
        var body = Data()
        
        // Add file field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"recording.m4a\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/m4a\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)
        
        // Add model field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
        body.append("whisper-large-v3\r\n".data(using: .utf8)!)
        
        // Add language field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"language\"\r\n\r\n".data(using: .utf8)!)
        body.append("ht\r\n".data(using: .utf8)!)
        
        // Add response_format field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"response_format\"\r\n\r\n".data(using: .utf8)!)
        body.append("json\r\n".data(using: .utf8)!)
        
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
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
            
            let decoder = JSONDecoder()
            let result = try decoder.decode(TranscriptionResponse.self, from: data)
            return result.text
            
        } catch let error as GroqError {
            throw error
        } catch {
            throw GroqError.networkError(error.localizedDescription)
        }
    }
    
    private func translateText(_ text: String) async throws -> String {
        var request = URLRequest(url: chatURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let payload: [String: Any] = [
            "model": "llama-3.3-70b-versatile",
            "messages": [
                [
                    "role": "system",
                    "content": "You are a professional translator. Translate the following Haitian Creole text to English. Only respond with the English translation, nothing else."
                ],
                [
                    "role": "user",
                    "content": text
                ]
            ],
            "temperature": 0.3,
            "max_tokens": 1024
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
                throw GroqError.translationFailed(errorMessage)
            }
            
            let decoder = JSONDecoder()
            let result = try decoder.decode(ChatResponse.self, from: data)
            
            guard let translation = result.choices.first?.message.content else {
                throw GroqError.invalidResponse
            }
            
            return translation
            
        } catch let error as GroqError {
            throw error
        } catch {
            throw GroqError.networkError(error.localizedDescription)
        }
    }
}
