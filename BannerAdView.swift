import Foundation
import SwiftUI
import UIKit

#if canImport(GoogleMobileAds)
import GoogleMobileAds
#endif

/// A SwiftUI wrapper for a banner ad. Uses GoogleMobileAds when available; otherwise shows a local placeholder.
struct BannerAdView: UIViewRepresentable {
    let adUnitID: String

    func makeUIView(context: Context) -> UIView {
        #if canImport(GoogleMobileAds)
        if NSClassFromString("GADBannerView") != nil {
            // Safe to use GADBannerView
            let banner = GADBannerView(adSize: GADCurrentOrientationAnchoredAdaptiveBannerAdSizeWithWidth(UIScreen.main.bounds.width))
            banner.adUnitID = adUnitID
            // rootViewController must be set to load ads
            if let root = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .flatMap({ $0.windows })
                .first(where: { $0.isKeyWindow })?.rootViewController {
                banner.rootViewController = root
            }
            banner.delegate = context.coordinator
            banner.load(GADRequest())
            return banner
        }
        #endif

        // Fallback placeholder view when GoogleMobileAds isn't available
        let label = UILabel()
        label.text = "Ad banner (test)"
        label.textAlignment = .center
        label.backgroundColor = UIColor.secondarySystemBackground
        label.textColor = UIColor.secondaryLabel
        return label
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        // no-op for now
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject {
        #if canImport(GoogleMobileAds)
        // Conform to delegate only when SDK available
        // Use optional methods via extension to avoid compile errors when SDK is missing
        #endif
    }
}
