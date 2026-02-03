//
//  CreoleTranslatorApp.swift
//  CreoleTranslator
//
//  Haitian Creole to English Translator iOS App
//

import SwiftUI
import GoogleMobileAds

@main
struct CreoleTranslatorApp: App {
    @Environment(\.scenePhase) private var scenePhase
    
    init() {
        // Initialize the Google Mobile Ads SDK early so ad requests can proceed.
        MobileAds.shared.start { status in }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                ATTAuthorization.requestIfNeeded() 
            }
        }
    }
}
