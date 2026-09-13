//
//  LanguageDetector.swift
//  CreoleTranslator
//
//  Offline Haitian Creole vs English guess for the direction auto-detect
//  feature. Word-list scoring only — no network, no tokens. Deliberately
//  conservative: short or mixed input comes back .unknown so the user's
//  chosen direction wins whenever the evidence is thin.
//

import Foundation

enum DetectedLanguage: Equatable {
    case creole, english, unknown
}

enum LanguageDetector {

    // Frequent Creole function words and everyday vocabulary. Ambiguous
    // tokens shared with English ("a", "men", "an") are left out on purpose.
    private static let creoleWords: Set<String> = [
        "mwen", "m", "ou", "w", "li", "l", "nou", "n", "yo", "y",
        "ap", "pa", "nan", "pou", "se", "ki", "sa", "gen", "genyen", "ak", "avèk", "avek",
        "kote", "kijan", "kisa", "kilè", "kile", "poukisa", "kiyès", "kiles", "konbyen",
        "bonjou", "bonswa", "mèsi", "mesi", "wi", "anpil", "tout", "moun", "bagay",
        "jodi", "jodia", "demen", "byen", "mal", "konnen", "konn", "vle", "bezwen",
        "ale", "al", "vini", "vin", "fè", "fe", "di", "wè", "tande", "pale", "manje",
        "dlo", "kay", "lajan", "travay", "tanpri", "souple", "eske", "èske", "tou",
        "yon", "sou", "apre", "avan", "jan", "epi", "oswa", "paske", "te", "pral",
        "t", "k", "kounye", "kounya", "isit", "la", "lakay", "papa", "manman", "pitit",
        "fanmi", "zanmi", "lavi", "bondye", "lè", "le", "jou", "swa", "maten", "aswè",
        "renmen", "ede", "chita", "kanpe", "dòmi", "domi", "bwè", "bwe", "achte", "vann",
        "pote", "kite", "rete", "fini", "kòmanse", "komanse", "ka", "kapab", "dwe", "fòk",
        "fok", "ta", "toujou", "janm", "jamè", "deja", "ankò", "anko", "pi", "plis", "mens",
        "gwo", "piti", "bèl", "bel", "bon", "move", "cho", "frèt", "fret", "nouvo", "vye",
        "mache", "machin", "lopital", "doktè", "dokte", "lekòl", "lekol", "legliz", "twalèt", "twalet",
    ]

    private static let englishWords: Set<String> = [
        "the", "an", "and", "or", "but", "is", "are", "was", "were", "be", "been", "am",
        "i", "you", "he", "she", "it", "we", "they", "me", "my", "your", "his", "her",
        "our", "their", "this", "that", "these", "those", "what", "where", "when", "how",
        "why", "who", "which", "to", "of", "in", "on", "at", "for", "with", "from", "by",
        "do", "does", "did", "not", "don't", "doesn't", "didn't", "can", "can't", "cannot",
        "will", "would", "should", "could", "have", "has", "had", "please", "thank",
        "thanks", "hello", "hi", "yes", "no", "good", "morning", "night", "want", "need",
        "go", "going", "come", "know", "like", "very", "much", "here", "there", "get",
        "got", "make", "see", "say", "said", "tell", "give", "take", "think", "look",
        "one", "two", "three", "day", "today", "tomorrow", "time", "help", "sorry",
        "water", "food", "house", "money", "work", "friend", "family", "bathroom",
        "i'm", "it's", "you're", "we're", "they're", "let's", "what's", "where's",
    ]

    // Single words that decide on their own (a one-word input has no context).
    private static let strongCreole: Set<String> = ["bonjou", "bonswa", "mèsi", "mesi", "tanpri", "souple", "wi", "mwen", "kijan", "kote", "anpil"]
    private static let strongEnglish: Set<String> = ["hello", "hi", "thanks", "thank", "please", "yes", "goodbye", "sorry", "okay", "ok"]

    // Letters that essentially never appear in English but are common in Creole.
    private static let creoleLetters: Set<Character> = ["è", "ò", "à", "ù", "ì"]

    static func detect(_ text: String) -> DetectedLanguage {
        let tokens = tokenize(text)
        guard !tokens.isEmpty else { return .unknown }

        if tokens.count == 1 {
            let w = tokens[0]
            if strongCreole.contains(w) { return .creole }
            if strongEnglish.contains(w) { return .english }
            if w.contains(where: { creoleLetters.contains($0) }) { return .creole }
            return .unknown
        }

        var creole = 0.0
        var english = 0.0
        for w in tokens {
            if creoleWords.contains(w) { creole += 1 }
            if englishWords.contains(w) { english += 1 }
            if w.contains(where: { creoleLetters.contains($0) }) { creole += 1.5 }
        }

        let total = creole + english
        guard total >= 2 else { return .unknown }
        let winner = max(creole, english)
        let loser = min(creole, english)
        // Clear margin and a clear majority; otherwise leave the choice to the user.
        guard winner >= loser + 1, winner / total >= 0.6 else { return .unknown }
        return creole > english ? .creole : .english
    }

    private static func tokenize(_ text: String) -> [String] {
        let lowered = text.lowercased()
        var tokens: [String] = []
        var current = ""
        for ch in lowered {
            if ch.isLetter || ch == "'" || ch == "’" {
                current.append(ch == "’" ? "'" : ch)
            } else if !current.isEmpty {
                tokens.append(current)
                current = ""
            }
        }
        if !current.isEmpty { tokens.append(current) }
        return tokens
    }
}
