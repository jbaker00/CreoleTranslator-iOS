//
//  BannerAdView.swift
//  CreoleTranslator
//
//  Google AdMob Banner Ad View (safe placeholder implementation)
//

import SwiftUI

/// A safe BannerAdView placeholder that avoids compile-time dependency on Google Mobile Ads SDK.
/// Replace the body implementation with a real UIViewRepresentable that creates a BannerView
/// when you have the SDK available and want real ads to load. Keeping this lightweight
/// placeholder prevents compile/link errors while the SDK/package is missing or being resolved.
struct BannerAdView: View {
    // Allow caller to pass width; default to screen width for previews
    var width: CGFloat = UIScreen.main.bounds.width

    // Use Google's test banner unit during development if you later wire the real SDK.
    // For now this placeholder displays the adUnitID and a framed rectangle so layout is stable.
    //let adUnitID: String = "ca-app-pub-3940256099942544/2934735716"
    let adUnitID: String = "ca-app-pub-7871017136061682/3584044139" // Replace with your real ad unit ID when using real ads
    var body: some View {
        VStack(spacing: 0) {
            Divider()
            HStack {
                Spacer()
                VStack(alignment: .center, spacing: 6) {
                    Text("Ad Banner Placeholder")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(adUnitID)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding(8)
            .background(Color(UIColor.tertiarySystemBackground))
        }
        .frame(width: width)
        .fixedSize(horizontal: false, vertical: true)
    }
}

// Helper to find a root view controller for presenting UIKit content if/when you add the real banner view
private extension UIApplication {
    func firstKeyWindowRootViewController() -> UIViewController? {
        connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow }
            .first?
            .rootViewController
    }
}

// Convenience to get the current key window from a scene
private extension UIWindowScene {
    var keyWindow: UIWindow? { windows.first(where: { $0.isKeyWindow }) }
}
