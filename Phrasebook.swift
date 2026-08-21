//
//  Phrasebook.swift
//  CreoleTranslator
//
//  Static, pre-translated common phrases. No network/LLM calls — works
//  offline and costs nothing to serve.
//
//  NOTE: drafted by an AI assistant, not a certified Haitian Creole
//  translator. Review before shipping, especially the Emergency/Medical
//  categories where correctness matters most. The "Know Your Rights"
//  category is the exception — it's sourced verbatim/officially-translated
//  from the ILRC Red Card (see citation above that category), not drafted
//  by us, but still worth a second look given the stakes.
//

import Foundation

struct PhrasebookEntry: Identifiable {
    let id = UUID()
    let english: String
    let creole: String
    /// Extra context shown below the phrase, for entries that need explaining
    /// (e.g. why a "translation" is intentionally left in English).
    var note: String? = nil
}

struct PhrasebookCategory: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let entries: [PhrasebookEntry]
}

enum Phrasebook {
    static let categories: [PhrasebookCategory] = [
        PhrasebookCategory(name: "Greetings", icon: "hand.wave.fill", entries: [
            PhrasebookEntry(english: "Hello / Good day", creole: "Bonjou"),
            PhrasebookEntry(english: "Good evening", creole: "Bonswa"),
            PhrasebookEntry(english: "How are you?", creole: "Kijan ou ye?"),
            PhrasebookEntry(english: "I'm fine, thank you", creole: "Mwen byen, mèsi"),
            PhrasebookEntry(english: "Thank you", creole: "Mèsi"),
            PhrasebookEntry(english: "You're welcome", creole: "Pa gen dekwa"),
            PhrasebookEntry(english: "Please", creole: "Souple"),
            PhrasebookEntry(english: "Goodbye", creole: "Orevwa"),
            PhrasebookEntry(english: "My name is...", creole: "Mwen rele..."),
            PhrasebookEntry(english: "Nice to meet you", creole: "Kontan konnen ou"),
        ]),
        PhrasebookCategory(name: "Basics", icon: "text.bubble.fill", entries: [
            PhrasebookEntry(english: "Yes", creole: "Wi"),
            PhrasebookEntry(english: "No", creole: "Non"),
            PhrasebookEntry(english: "Excuse me", creole: "Eskize m"),
            PhrasebookEntry(english: "I don't understand", creole: "Mwen pa konprann"),
            PhrasebookEntry(english: "Do you speak English?", creole: "Èske ou pale angle?"),
            PhrasebookEntry(english: "How much does this cost?", creole: "Konbyen sa koute?"),
            PhrasebookEntry(english: "Where is the bathroom?", creole: "Kote twalèt la?"),
            PhrasebookEntry(english: "One, two, three", creole: "En, de, twa"),
        ]),
        // Source: Immigrant Legal Resource Center (ILRC) "Red Card" — the standard,
        // widely-distributed know-your-rights card for immigration/ICE encounters.
        // English: https://www.ilrc.org/sites/default/files/documents/red_card-self_srv-english.pdf
        // Haitian Creole (ILRC's own official translation):
        // https://www.ilrc.org/sites/default/files/2023-06/Artwork%20for%20Printing%20Your%20Own%20Red%20Cards%20-%20Haitian%20Creole.pdf
        // ILRC's own card keeps the legal statement (the amendment-citing paragraph you
        // hand to an officer) in English on every language version — that's preserved
        // below, not translated by us. Fetched/verified 2026-08-21.
        PhrasebookCategory(name: "Know Your Rights", icon: "hand.raised.fill", entries: [
            PhrasebookEntry(
                english: "Do not open the door if an immigration agent is knocking",
                creole: "Pa louvri pòt la si yon ajan imigrasyon frape pòt la"
            ),
            PhrasebookEntry(
                english: "Do not answer any questions from an immigration officer. You have the right to remain silent",
                creole: "Pa reponn okenn keksyon yon ofisye imigrasyon si yo eseye pale avèk ou. Ou gen dwa pou rete an silans"
            ),
            PhrasebookEntry(
                english: "Do not sign anything without speaking to a lawyer first. You have the right to speak with a lawyer",
                creole: "Pa siyen anyen san w' pa pale anvan avèk yon avoka. Ou gen dwa pale ak yon avoka"
            ),
            PhrasebookEntry(
                english: "Am I free to leave?",
                creole: "Èske m' lib pou ale?"
            ),
            PhrasebookEntry(
                english: "I want to speak to a lawyer",
                creole: "Mwen vle pale ak yon avoka"
            ),
            PhrasebookEntry(
                english: "Give this card to the officer. If you're inside, show it through the window or slide it under the door",
                creole: "Bay ofisye a kat sa a. Si ou anndan, montre l nan fenèt la oswa glise l anba pòt la"
            ),
            PhrasebookEntry(
                english: "Legal statement — show or hand this to the officer",
                creole: "I do not wish to speak with you, answer your questions, or sign or hand you any documents based on my 5th Amendment rights under the United States Constitution. I do not give you permission to enter my home based on my 4th Amendment rights under the United States Constitution unless you have a warrant to enter, signed by a judge or magistrate with my name on it that you slide under the door. I do not give you permission to search any of my belongings based on my 4th Amendment rights. I choose to exercise my constitutional rights.",
                note: "Kept in English on purpose, matching ILRC's own card — this exact wording is what's legally recognized, so it isn't translated."
            ),
        ]),
        PhrasebookCategory(name: "Directions", icon: "signpost.right.fill", entries: [
            PhrasebookEntry(english: "Where is...?", creole: "Kote... ye?"),
            PhrasebookEntry(english: "Left", creole: "Goch"),
            PhrasebookEntry(english: "Right", creole: "Dwat"),
            PhrasebookEntry(english: "Straight ahead", creole: "Toudwat"),
            PhrasebookEntry(english: "Near / Far", creole: "Toupre / Lwen"),
            PhrasebookEntry(english: "Can you help me find...?", creole: "Èske ou ka ede m jwenn...?"),
            PhrasebookEntry(english: "I am lost", creole: "Mwen pèdi"),
        ]),
        PhrasebookCategory(name: "Emergency", icon: "exclamationmark.triangle.fill", entries: [
            PhrasebookEntry(english: "Help!", creole: "Anmwe!"),
            PhrasebookEntry(english: "Call the police", creole: "Rele lapolis"),
            PhrasebookEntry(english: "Call an ambulance", creole: "Rele anbilans"),
            PhrasebookEntry(english: "I need a doctor", creole: "Mwen bezwen yon doktè"),
            PhrasebookEntry(english: "Fire!", creole: "Dife!"),
            PhrasebookEntry(english: "It's an emergency", creole: "Se yon ijans"),
            PhrasebookEntry(english: "Where is the hospital?", creole: "Kote lopital la?"),
            PhrasebookEntry(english: "I am in danger", creole: "Mwen nan danje"),
        ]),
        PhrasebookCategory(name: "Medical", icon: "cross.case.fill", entries: [
            PhrasebookEntry(english: "I am sick", creole: "Mwen malad"),
            PhrasebookEntry(english: "I have a headache", creole: "Mwen gen tèt fè mal"),
            PhrasebookEntry(english: "I have a fever", creole: "Mwen gen lafyèv"),
            PhrasebookEntry(english: "It hurts here", creole: "Li fè mal isit la"),
            PhrasebookEntry(english: "I am allergic to...", creole: "Mwen fè alèji ak..."),
            PhrasebookEntry(english: "I need medicine", creole: "Mwen bezwen medikaman"),
            PhrasebookEntry(english: "Are you okay?", creole: "Èske ou byen?"),
            PhrasebookEntry(english: "I need water", creole: "Mwen bezwen dlo"),
        ]),
        PhrasebookCategory(name: "Travel", icon: "airplane", entries: [
            PhrasebookEntry(english: "Where is the airport?", creole: "Kote ayewopò a ye?"),
            PhrasebookEntry(english: "I would like a taxi", creole: "Mwen ta renmen yon taksi"),
            PhrasebookEntry(english: "How do I get to...?", creole: "Kijan pou m rive nan...?"),
            PhrasebookEntry(english: "What time is it?", creole: "Ki lè li ye?"),
            PhrasebookEntry(english: "I am a tourist", creole: "Mwen se yon touris"),
            PhrasebookEntry(english: "Can you recommend a restaurant?", creole: "Èske ou ka rekòmande yon restoran?"),
            PhrasebookEntry(english: "Safe travels", creole: "Bon vwayaj"),
        ]),
    ]
}
