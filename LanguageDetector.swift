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
    case creole, english, spanish, unknown
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
        // Added 2026-11 from two months of proxy logs (wrong-direction misses).
        "mw", "map", "pap", "tap", "ke", "kè", "ke'm", "konsa", "sak", "sak'ap", "sakap", "kap", "gade",
        "gad", "ba", "pran", "rive", "tounen", "soti", "antre", "monte", "desann", "rele", "reponn", "ekri",
        "chache", "jwenn", "mete", "pèdi", "pedi", "peye", "voye", "resevwa", "madanm", "frè", "sè",
        "gason", "tifi", "timoun", "granmoun", "mesye", "medam", "cheri", "doudou", "lendi", "madi",
        "mèkredi", "mekredi", "jedi", "vandredi", "samdi", "dimanch", "semèn", "semen", "mwa", "ane",
        "lane", "èd", "kontan", "tris", "malad", "fatige", "grangou", "swaf", "lèd", "vre", "menm",
        "sèlman", "selman", "petèt", "petet", "kounyea", "nap", "n'ap", "m'ap", "w'ap", "l'ap", "y'ap",
        "mwen'm", "pam", "paw", "poum", "pouw", "avèm", "avew", "sim", "siw", "kem", "kew", "kibò", "kibo",
        "sa'k", "koman", "kòman", "komanw", "jezi", "senyè", "senye", "beni", "lapriyè", "lapriye",
        "pwoblèm", "pwoblem", "kichòy", "kichoy", "anyen", "okenn", "chak", "plizyè", "plizye", "kèk",
        "kek", "lòt", "isi", "lòtbò", "lotbo", "deyò", "deyo", "anndan", "anlè", "anba", "devan", "dèyè",
        "deye", "bò", "youn", "twa", "senk", "sèt", "uit", "nèf",
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
        // Added 2026-11 from two months of proxy logs. Words that are also Creole
        // spellings ("men", "pale", "lot", "son", "so") stay out.
        "as", "if", "than", "then", "because", "about", "into", "over", "after", "before", "up", "down",
        "out", "off", "just", "also", "only", "even", "still", "again", "always", "never", "now", "well",
        "back", "too", "any", "some", "all", "each", "every", "other", "another", "more", "most", "many",
        "few", "new", "old", "big", "small", "little", "right", "wrong", "us", "him", "them", "its", "mine",
        "yours", "myself", "yourself", "who's", "that's", "there's", "he's", "she's", "i'll", "you'll",
        "we'll", "they'll", "i've", "you've", "we've", "they've", "i'd", "you'd", "isn't", "aren't",
        "wasn't", "weren't", "won't", "wouldn't", "shouldn't", "couldn't", "haven't", "hasn't", "being",
        "having", "doing", "done", "went", "gone", "came", "coming", "getting", "made", "making", "saw",
        "seen", "saying", "told", "gave", "given", "took", "taken", "thought", "looked", "looking", "love",
        "loved", "miss", "call", "called", "talk", "talking", "speak", "eat", "eating", "drink", "sleep",
        "wait", "stop", "start", "send", "sent", "buy", "bring", "put", "keep", "let", "leave", "left",
        "feel", "feeling", "try", "find", "found", "show", "ask", "asked", "answer", "working", "live",
        "lived", "use", "used", "baby", "girl", "boy", "man", "woman", "wife", "husband", "mother",
        "father", "mom", "dad", "brother", "sister", "daughter", "child", "children", "kids", "people",
        "person", "guy", "home", "school", "church", "hospital", "doctor", "store", "car", "phone", "job",
        "office", "room", "door", "street", "city", "country", "week", "month", "year", "hour", "minute",
        "tonight", "yesterday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday",
        "sunday", "happy", "sad", "sick", "tired", "hungry", "beautiful", "pretty", "nice", "great", "bad",
        "better", "best", "ready", "sure", "okay", "ok", "fine", "really", "maybe", "how's", "welcome",
        "bye", "goodbye", "god", "jesus", "lord", "bless", "without", "between", "around", "through",
        "under", "during", "while", "until", "since", "four", "five", "six", "seven", "eight", "nine",
        "ten", "first", "last", "next",
    ]

    // Latin American Spanish, for the Spanish ↔ Creole pair. Words that are also
    // Creole ("la", "se", "te", "y", "mal", "yo" = they, "al", "le") are left out.
    private static let spanishWords: Set<String> = [
        "el", "los", "las", "un", "una", "unos", "es", "está", "están", "estoy", "eres", "soy", "somos",
        "son", "que", "qué", "por", "para", "con", "sin", "pero", "porque", "como", "cómo", "cuando",
        "cuándo", "donde", "dónde", "quien", "quién", "cuál", "cuánto", "cuanto", "este", "esta", "esto",
        "ese", "esa", "eso", "mi", "mis", "tu", "tus", "su", "sus", "nuestro", "usted", "ustedes", "ellos",
        "ellas", "nosotros", "él", "ella", "me", "lo", "les", "nos", "del", "muy", "más", "mas", "también",
        "tambien", "ya", "hay", "tengo", "tiene", "tienes", "tienen", "quiero", "quiere", "quieres",
        "necesito", "necesita", "puedo", "puede", "puedes", "voy", "va", "vamos", "van", "hacer", "hago",
        "hace", "decir", "digo", "dice", "sé", "sabe", "ver", "veo", "hola", "gracias", "favor", "buenos",
        "buenas", "días", "dias", "tardes", "noches", "adiós", "adios", "sí", "bien", "bueno", "malo",
        "aquí", "aqui", "allí", "ahora", "hoy", "mañana", "ayer", "siempre", "nunca", "nada", "algo",
        "todo", "todos", "mucho", "mucha", "poco", "casa", "agua", "comida", "dinero", "trabajo", "amigo",
        "familia", "baño", "médico", "medico", "ayuda", "alto", "pare", "documentos", "identificación",
        "nombre", "señor", "señora", "hombre", "mujer", "niño", "niña", "hijo", "hija", "madre", "padre",
        "hermano", "hermana", "dolor", "herido", "calle", "policía", "policia", "soldado", "arma", "armas",
        "manos", "peligro", "seguro", "tranquilo", "espere", "venga", "siéntese", "muéstreme", "abra",
        "cierre", "vehículo", "carro", "habla", "hablo", "hablas", "entiendo", "entiende", "llamo", "llama",
        "vive", "vivo",
    ]
    private static let strongSpanish: Set<String> = ["hola", "gracias", "sí", "adiós", "adios", "alto", "ayuda", "dónde", "donde",
                                                     "cuánto", "qué", "bueno", "buenos", "buenas", "perdón", "perdon", "disculpe"]
    // Creole-list words that are everyday Spanish too; they don't vote for
    // Creole when the pair is Spanish ↔ Creole ("se te ve bien").
    private static let creoleSharedWithSpanish: Set<String> = ["la", "se", "te", "y", "mal", "yo", "al", "le", "ta", "si", "pa", "sa", "di", "ki", "li",
                                                               "tout", "ale", "vini", "bon", "papa", "pi", "m", "n", "l", "t", "k", "w", "fe", "sou", "jan", "ti"]
    private static let weakSpanish: Set<String> = ["me", "mi", "tu", "su", "lo", "es", "un", "va", "ya", "son", "mas", "ver"]
    // Acute accents and ñ: Spanish uses them, Creole (grave accents only) does not.
    private static let spanishLetters: Set<Character> = ["á", "é", "í", "ó", "ú", "ñ", "ü"]

    // Single words that decide on their own (a one-word input has no context).
    private static let strongCreole: Set<String> = ["bonjou", "bonswa", "mèsi", "mesi", "tanpri", "souple", "wi", "mwen", "kijan", "kote", "anpil"]
    private static let strongEnglish: Set<String> = [
        "hello", "hi", "thanks", "thank", "please", "yes", "goodbye", "sorry", "okay", "ok",
        "hey", "bye", "welcome", "where", "when", "why", "what", "how", "who", "good", "go", "come", "need",
        "want", "have", "love", "stop", "wait", "help", "yeah", "yep", "nope", "goodnight", "baby",
        "beautiful", "hungry", "tired", "happy", "today", "tomorrow", "yesterday", "because", "maybe",
        "really", "never", "always",
    ]

    // English-list words that are also common Creole spellings once accents are
    // dropped ("we" = wè, "on" = yon, "do" = back). Fine as one vote among
    // several, but never enough to decide a short phrase alone.
    private static let weakEnglish: Set<String> = ["an", "no", "on", "we", "do", "to", "me", "he", "at", "or", "in", "i", "one", "be", "am"]

    // Letters that essentially never appear in English but are common in Creole.
    private static let creoleLetters: Set<Character> = ["è", "ò", "à", "ù", "ì"]

    /// Creole vs the other language of the selected pair. `partner` is the
    /// non-Creole side (English or Spanish); the answer is never the third
    /// language, because the app can't translate out of the pair anyway.
    static func detect(_ text: String, partner: Language = .english) -> DetectedLanguage {
        let tokens = tokenize(text)
        guard !tokens.isEmpty else { return .unknown }

        let spanish = partner == .spanish
        let otherWords = spanish ? spanishWords : englishWords
        let otherStrong = spanish ? strongSpanish : strongEnglish
        let otherWeak = spanish ? weakSpanish : weakEnglish
        let other: DetectedLanguage = spanish ? .spanish : .english
        func hasCreoleLetter(_ w: String) -> Bool { w.contains(where: { creoleLetters.contains($0) }) }
        func hasOtherLetter(_ w: String) -> Bool { spanish && w.contains(where: { spanishLetters.contains($0) }) }

        if tokens.count == 1 {
            let w = tokens[0]
            if strongCreole.contains(w) { return .creole }
            if otherStrong.contains(w) { return other }
            if hasCreoleLetter(w) { return .creole }
            if hasOtherLetter(w) { return other }
            return .unknown
        }

        var creole = 0.0
        var otherScore = 0.0
        var weakOnly = true
        for w in tokens {
            if creoleWords.contains(w), !(spanish && creoleSharedWithSpanish.contains(w)) { creole += 1; weakOnly = false }
            if otherWords.contains(w) {
                otherScore += 1
                if !otherWeak.contains(w) { weakOnly = false }
            }
            if hasCreoleLetter(w) { creole += 1.5; weakOnly = false }
            if hasOtherLetter(w) { otherScore += 1.5; weakOnly = false }
        }

        let total = creole + otherScore
        // Two known words normally; phrases of 2–3 words ("Go home", "Pou
        // dimanch") can decide on one, as long as it isn't an ambiguous one.
        let needed: Double = tokens.count <= 3 && !weakOnly ? 1 : 2
        guard total >= needed else { return .unknown }
        let winner = max(creole, otherScore)
        let loser = min(creole, otherScore)
        // Clear margin and a clear majority; otherwise leave the choice to the user.
        // Strictly more than 60%, so a 3–2 split (code-switching: "Jodia fem 4
        // jou back to the gym") stays with the user's direction.
        guard winner >= loser + 1, winner / total > 0.6 else { return .unknown }
        return creole > otherScore ? .creole : other
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
