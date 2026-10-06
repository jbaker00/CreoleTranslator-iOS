//
//  BannerAdView.swift
//  CreoleTranslator
//
//  Google AdMob Banner Ad View
//

import SwiftUI
import GoogleMobileAds

/// Real AdMob banner ad view that loads and displays ads.
/// Uses an anchored adaptive size: it fills the full width and earns more than fixed 320×50.
struct BannerAdView: UIViewRepresentable {
    let adSize: AdSize
#if DEBUG
    // Google's test unit — clicking real ads on our own devices risks AdMob invalid-traffic flags.
    let adUnitID: String = "ca-app-pub-3940256099942544/2435281174"
#else
    let adUnitID: String = "ca-app-pub-7871017136061682/3584044139"
#endif

    /// Adaptive size for the given container width. Must be called on the main thread.
    static func size(forWidth width: CGFloat) -> AdSize {
        currentOrientationAnchoredAdaptiveBanner(width: width)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        /// The size we last requested. BannerView.adSize can't be used for this: right
        /// after init it reads back 0×0 for adaptive sizes, and re-setting it then
        /// re-loads the ad at double the size (880pt wide on a 440pt screen, clipped).
        var requestedSize: CGSize = .zero
    }

    func makeUIView(context: Context) -> BannerView {
        let bannerView = BannerView(adSize: adSize)
        bannerView.adUnitID = adUnitID
        bannerView.rootViewController = UIApplication.shared.firstKeyWindowRootViewController()
        context.coordinator.requestedSize = adSize.size
        bannerView.load(Request())
        return bannerView
    }

    func updateUIView(_ uiView: BannerView, context: Context) {
        // Width changed (rotation, iPad split view): request an ad at the new size.
        guard context.coordinator.requestedSize != adSize.size else { return }
        context.coordinator.requestedSize = adSize.size
        uiView.adSize = adSize
        uiView.load(Request())
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
