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

protocol TranslationService {
    func processAudio(fileURL: URL) async throws -> TranslationResult
}

class GroqService: TranslationService {
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

// New service that calls OpenAI's Whisper for transcription and Meta-hosted LLama for translation
class OpenAIMetaService: TranslationService {
    private let openAIKey: String
    private let metaKey: String?
    private let metaURL: URL?
    
    init(openAIKey: String, metaKey: String?, metaURL: URL?) {
        self.openAIKey = openAIKey
        self.metaKey = metaKey
        self.metaURL = metaURL
    }
    
    func processAudio(fileURL: URL) async throws -> TranslationResult {
        let transcription = try await transcribeWithOpenAI(fileURL: fileURL)
        let translation = try await translateWithMeta(text: transcription)
        return TranslationResult(transcription: transcription, translation: translation, provider: "OpenAI Whisper + Meta Llama (self-hosted)")
    }
    
    private func transcribeWithOpenAI(fileURL: URL) async throws -> String {
        // OpenAI Whisper endpoint (OpenAI hosted) - example using the OpenAI speech-to-text REST API
        // NOTE: adjust the endpoint and model name according to OpenAI's API docs and SDK versions.
        let url = URL(string: "https://api.openai.com/v1/audio/transcriptions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(openAIKey)", forHTTPHeaderField: "Authorization")
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        let audioData = try Data(contentsOf: fileURL)
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"recording.m4a\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/m4a\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
        body.append("whisper-1\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw GroqError.transcriptionFailed(String(data: data, encoding: .utf8) ?? "OpenAI transcription failed")
        }
        let decoder = JSONDecoder()
        struct OpenAITranscription: Codable { let text: String }
        let result = try decoder.decode(OpenAITranscription.self, from: data)
        return result.text
    }
    
    private func translateWithMeta(text: String) async throws -> String {
        // Meta-hosted LLama translation endpoint - requires metaAPIURL and metaAPIKey
        guard let metaURL = metaURL else { throw GroqError.invalidResponse }
        var request = URLRequest(url: metaURL)
        request.httpMethod = "POST"
        if let key = metaKey { request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization") }
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let payload: [String: Any] = [
            "inputs": "Translate the following Haitian Creole text to English. Only output the English translation:\n\n\(text)",
            "parameters": ["temperature": 0.3, "max_new_tokens": 1024]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw GroqError.translationFailed(String(data: data, encoding: .utf8) ?? "Meta translation failed")
        }
        // Response parsing depends on provider; assume a generic {"generated_text":"..."} or HF style
        if let decoded = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let gen = decoded["generated_text"] as? String {
            return gen
        }
        // Fallback to try parsing array of dicts (huggingface inference API style)
        if let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
           let first = arr.first, let gen = first["generated_text"] as? String {
            return gen
        }
        return String(data: data, encoding: .utf8) ?? ""
    }
}
