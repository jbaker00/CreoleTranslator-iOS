//
//  ATTAuthorization.swift
//  CreoleTranslator
//
//  Handles App Tracking Transparency (ATT) permission flow
//

import Foundation 
import AppTrackingTransparency
import AdSupport

// Simple namespace for ATT-related utilities
enum ATTAuthorization {
    // Only request tracking authorization if we haven't asked before. This avoids repeat prompts
    // and follows Apple's guidance for respectful timing and context.
    static func requestIfNeeded() {
        guard ATTrackingManager.trackingAuthorizationStatus == .notDetermined else { return }
        // Small delay gives the app time to finish launching UI before presenting the system dialog,
        // creating a smoother experience and avoiding potential presentation warnings.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            ATTrackingManager.requestTrackingAuthorization { _ in
                // Optional: react to the new status (e.g., configure SDKs for limited tracking if denied).
            }
        }
    }
}
