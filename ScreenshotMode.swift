//
//  ScreenshotMode.swift
//  CreoleTranslator
//
//  DEBUG-only: launch with `-shotScene <scene>` (UserDefaults argument domain) to
//  open straight to a screen for App Store / Custom Product Page screenshots.
//  Add `-userConsentForAIDataSharing YES` to skip the consent sheet.
//  Scenes: medical, travel, family (result cards), phrasebook-<Category>.
//

import Foundation

enum ScreenshotMode {
#if DEBUG
    static var scene: String? { UserDefaults.standard.string(forKey: "shotScene") }
#else
    static var scene: String? { nil }
#endif

    static var isActive: Bool { scene != nil }

    /// Category name to scroll the phrasebook to, e.g. "Medical".
    static var phrasebookCategory: String? {
        guard let scene, scene.hasPrefix("phrasebook-") else { return nil }
        return String(scene.dropFirst("phrasebook-".count))
    }

    /// Phrasebook categories with the screenshot category (if any) moved to the top.
    static var orderedPhrasebookCategories: [PhrasebookCategory] {
        guard let name = phrasebookCategory else { return Phrasebook.categories }
        return Phrasebook.categories.filter { $0.name == name } + Phrasebook.categories.filter { $0.name != name }
    }

    /// Sample result for the result-card scenes: (source, translation, direction).
    static var sampleResult: (String, String, TranslationDirection)? {
        switch scene {
        case "medical":
            return ("Where does it hurt? Show me with your finger.",
                    "Ki kote ou santi doulè a? Montre m ak dwèt ou.",
                    .englishToCreole)
        case "travel":
            return ("How much does a taxi to Jacmel cost?",
                    "Konbyen kòb yon taksi pou ale Jakmèl koute?",
                    .englishToCreole)
        case "family":
            return ("Grann, mwen sonje w anpil. Ki lè w ap vin vizite nou?",
                    "Grandma, I miss you so much. When are you coming to visit us?",
                    .creoleToEnglish)
        default:
            return nil
        }
    }
}
