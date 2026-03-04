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

struct DataPrivacyConsentView: View {
    @ObservedObject var consentManager: DataPrivacyConsent
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                // Icon
                Image(systemName: "shield.checkered")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)

                // Title
                Text("Data Privacy Notice")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)

                // Explanation
                VStack(alignment: .leading, spacing: 12) {
                    Text("This app uses AI services to translate your speech. To provide this functionality:")
                        .font(.body)
                        .foregroundColor(.primary)

                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .top, spacing: 8) {
                            Text("•")
                            Text("**What data is sent:** Audio recordings of your speech")
                        }

                        HStack(alignment: .top, spacing: 8) {
                            Text("•")
                            Text("**Who receives it:** Groq AI (for transcription and translation) and OpenAI (for text-to-speech)")
                        }

                        HStack(alignment: .top, spacing: 8) {
                            Text("•")
                            Text("**Purpose:** To transcribe, translate, and generate speech audio")
                        }

                        HStack(alignment: .top, spacing: 8) {
                            Text("•")
                            Text("**Retention:** Audio is processed temporarily and not stored on your device")
                        }
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                    Text("By continuing, you consent to sharing your audio data with these third-party AI services. You can revoke this consent at any time in the app settings.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                }
                .padding(.horizontal)

                // Buttons
                VStack(spacing: 12) {
                    Button(action: {
                        consentManager.grantConsent()
                    }) {
                        Text("I Understand and Consent")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }

                    Button(action: {
                        // User declines - they can't use the app features
                        consentManager.revokeConsent()
                    }) {
                        Text("Decline")
                            .fontWeight(.medium)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color(UIColor.secondarySystemBackground))
                            .foregroundColor(.primary)
                            .cornerRadius(10)
                    }
                }
                .padding(.horizontal)
            }
            .padding(24)
            .background(Color(UIColor.systemBackground))
            .cornerRadius(20)
            .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
            .padding(.horizontal, 30)
        }
    }
}

#Preview {
    DataPrivacyConsentView(consentManager: DataPrivacyConsent())
}
