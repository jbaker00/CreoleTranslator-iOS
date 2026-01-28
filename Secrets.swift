import Foundation

/// Helper to load sensitive configuration like API keys from multiple sources without hard-coding.
/// Order of precedence:
/// 1. Environment variables
/// 2. Secrets.plist in the app bundle (gitignored in your repo)
/// 3. Info.plist keys (less secure, optional)
struct Secrets {
    private static func lookup(key: String) -> String? {
        // 1) Environment
        if let env = ProcessInfo.processInfo.environment[key], !env.isEmpty {
            return env
        }
        // 2) Secrets.plist in bundle
        if let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
           let data = try? Data(contentsOf: url),
           let dict = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any],
           let val = dict[key] as? String,
           !val.isEmpty {
            return val
        }
        // 3) Info.plist
        if let infoVal = Bundle.main.object(forInfoDictionaryKey: key) as? String, !infoVal.isEmpty {
            return infoVal
        }
        return nil
    }

    // Existing Groq API key (kept for compatibility)
    static var groqAPIKey: String? { lookup(key: "GROQ_API_KEY") }

    // OpenAI key (for Whisper hosted by OpenAI)
    static var openAIKey: String? { lookup(key: "OPENAI_API_KEY") }

    // Meta / Llama hosting key and URL. Many Meta-hosted endpoints require a base URL + Bearer key.
    // Use META_API_KEY and META_API_URL in your environment or Secrets.plist.
    static var metaAPIKey: String? { lookup(key: "META_API_KEY") }
    static var metaAPIURL: String? { lookup(key: "META_API_URL") }
}
