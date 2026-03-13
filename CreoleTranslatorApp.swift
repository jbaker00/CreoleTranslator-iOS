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
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var metricsManager = MetricsManager()

    init() {
        // Firebase must be configured before any other Firebase service
        FirebaseApp.configure()
        // Initialize Google Mobile Ads SDK
        MobileAds.shared.start { status in }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(metricsManager)
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                ATTAuthorization.requestIfNeeded()
                metricsManager.startSession()
            } else if newPhase == .background {
                metricsManager.endSession()
            }
        }
    }
}
