//
//  Phrasebook.swift
//  CreoleTranslator
//
//  Static, pre-translated common phrases. No network/LLM calls — works
//  offline and costs nothing to serve.
//
//  NOTE: drafted by an AI assistant, not a certified Haitian Creole
//  translator, then corrected by a native speaker. Review before shipping
//  any further changes, especially Emergency/Medical.
//

import Foundation

struct PhrasebookEntry: Identifiable {
    let id = UUID()
    let english: String
    let creole: String
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
            PhrasebookEntry(english: "Hello / Good day", creole: "Allo bonjou"),
            PhrasebookEntry(english: "Good evening", creole: "Bonswa"),
            PhrasebookEntry(english: "How are you?", creole: "Kijan ou ye?"),
            PhrasebookEntry(english: "I'm fine, thank you", creole: "Mwen byen, mèsi"),
            PhrasebookEntry(english: "Thank you", creole: "Mèsi"),
            PhrasebookEntry(english: "You're welcome", creole: "Pa dekwa"),
            PhrasebookEntry(english: "Please", creole: "Sil vous plè"),
            PhrasebookEntry(english: "Goodbye", creole: "Orevwa"),
            PhrasebookEntry(english: "My name is...", creole: "Mwen rele..."),
            PhrasebookEntry(english: "Nice to meet you", creole: "Mwen byen kontan fè konesans ou"),
        ]),
        PhrasebookCategory(name: "Basics", icon: "text.bubble.fill", entries: [
            PhrasebookEntry(english: "Yes", creole: "Wi"),
            PhrasebookEntry(english: "No", creole: "Non"),
            PhrasebookEntry(english: "Excuse me", creole: "Eskize m"),
            PhrasebookEntry(english: "I don't understand", creole: "Mwen pa konprann"),
            PhrasebookEntry(english: "Do you speak English?", creole: "Èske ou pale angle?"),
            PhrasebookEntry(english: "How much does this cost?", creole: "Konbyen sa koute?"),
            PhrasebookEntry(english: "Where is the bathroom?", creole: "Kote twalèt la ye sil vous plè"),
            PhrasebookEntry(english: "One, two, three", creole: "En, de, twa"),
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
            PhrasebookEntry(english: "Where is the airport?", creole: "Kote ayewopò a ye sil vous plè"),
            PhrasebookEntry(english: "I would like a taxi", creole: "Mwen bezwen yon taksi sil vous plè"),
            PhrasebookEntry(english: "How do I get to...?", creole: "Kijan pou m rive nan...?"),
            PhrasebookEntry(english: "What time is it?", creole: "Ki lè li ye?"),
            PhrasebookEntry(english: "I am a tourist", creole: "Mwen se yon touris"),
            PhrasebookEntry(english: "Can you recommend a restaurant?", creole: "Èske ou ka rekòmande yon restoran?"),
            PhrasebookEntry(english: "Safe travels", creole: "Bon vwayaj"),
        ]),
    ]
}
