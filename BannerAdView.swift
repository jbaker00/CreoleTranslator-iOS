//
//  BannerAdView.swift
//  CreoleTranslator
//
//  Google AdMob Banner Ad View
//

import SwiftUI
import GoogleMobileAds

/// Real AdMob banner ad view that loads and displays ads
struct BannerAdView: UIViewRepresentable {
    var width: CGFloat = UIScreen.main.bounds.width
    let adUnitID: String = "ca-app-pub-7871017136061682/3584044139"
    
    func makeUIView(context: Context) -> BannerView {
        let bannerView = BannerView(adSize: AdSizeBanner)
        bannerView.adUnitID = adUnitID
        bannerView.rootViewController = UIApplication.shared.firstKeyWindowRootViewController()
        bannerView.load(Request())
        return bannerView
    }
    
    func updateUIView(_ uiView: BannerView, context: Context) {
        // No-op: banner handles its own updates
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
