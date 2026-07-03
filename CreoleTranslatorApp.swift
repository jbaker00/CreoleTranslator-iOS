//
//  CreoleTranslatorApp.swift
//  CreoleTranslator
//
//  Haitian Creole to English Translator iOS App
//

import SwiftUI
import GoogleMobileAds
import FirebaseCore

@main
struct CreoleTranslatorApp: App {
    init() {
        // Firebase must be configured before any other Firebase service
        FirebaseApp.configure()
        // Initialize Google Mobile Ads SDK
        MobileAds.shared.start { status in }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        // ATT is requested from ContentView after the privacy consent
        // sheet is answered, so first-launch dialogs don't stack.
    }
}
