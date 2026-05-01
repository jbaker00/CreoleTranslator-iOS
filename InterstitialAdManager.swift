import GoogleMobileAds
import UIKit

// Shows an interstitial ad every interstitialInterval successful translations per session.
// Replace adUnitID with the real unit ID from your AdMob dashboard before release.
@MainActor
class InterstitialAdManager: NSObject, ObservableObject, FullScreenContentDelegate {

    static let interstitialInterval = 25

    private let adUnitID = "ca-app-pub-7871017136061682/1614363987"

    private var interstitial: InterstitialAd?

    override init() {
        super.init()
        preload()
    }

    func preload() {
        Task {
            do {
                interstitial = try await InterstitialAd.load(with: adUnitID, request: Request())
                interstitial?.fullScreenContentDelegate = self
            } catch {
                // No ad available; will retry on next preload() call
            }
        }
    }

    func showIfReady() {
        guard let ad = interstitial,
              let root = UIApplication.shared
                .connectedScenes
                .compactMap({ ($0 as? UIWindowScene)?.windows.first(where: { $0.isKeyWindow }) })
                .first?
                .rootViewController
        else {
            preload()
            return
        }
        ad.present(from: root)
    }

    // MARK: FullScreenContentDelegate

    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        interstitial = nil
        preload()
    }

    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        interstitial = nil
        preload()
    }
}
