//
//  DataPrivacyConsent.swift
//  CreoleTranslator
//
//  Manages user consent for sharing audio data with third-party AI services.
//  Required for App Store Guidelines 5.1.1(i) and 5.1.2(i) compliance.
//

import Foundation
import SwiftUI

class DataPrivacyConsent: ObservableObject {
    private let consentKey = "userConsentForAIDataSharing"

    @Published var hasConsented: Bool {
        didSet {
            UserDefaults.standard.set(hasConsented, forKey: consentKey)
        }
    }

    init() {
        self.hasConsented = UserDefaults.standard.bool(forKey: consentKey)
    }

    func grantConsent() {
        hasConsented = true
    }

    func revokeConsent() {
        hasConsented = false
    }

    var shouldShowConsentDialog: Bool {
        return !hasConsented
    }
}

// Presented as a .sheet — compact native bottom sheet, not a blocking overlay.
struct DataPrivacyConsentView: View {
    @ObservedObject var consentManager: DataPrivacyConsent

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "waveform.and.mic")
                .font(.system(size: 36))
                .foregroundColor(.accentColor)

            Text("Voice & Privacy")
                .font(.title3)
                .fontWeight(.bold)

            Text("Your speech is sent to Groq AI for transcription and translation. Audio is processed temporarily and never stored.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            Text("Audio data is not retained after processing. You can revoke this in Settings at any time.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            VStack(spacing: 10) {
                Button(action: { consentManager.grantConsent() }) {
                    Text("Allow & Continue")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }

                Button(action: { consentManager.revokeConsent() }) {
                    Text("Not Now")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 24)

            Spacer(minLength: 16)
        }
        .padding(.top, 8)
        .presentationDetents([.height(360)])
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(true)
    }
}

#Preview {
    DataPrivacyConsentView(consentManager: DataPrivacyConsent())
}
