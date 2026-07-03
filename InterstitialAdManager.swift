import FirebaseAnalytics
import GoogleMobileAds
import UIKit

// Shows an interstitial ad every interstitialInterval successful translations,
// capped per session and spaced by a minimum time gap so rapid translators
// aren't hit with back-to-back full-screen ads.
@MainActor
class InterstitialAdManager: NSObject, ObservableObject, FullScreenContentDelegate {

    static let interstitialInterval = 4
    static let maxPerSession = 6
    static let minSecondsBetweenShows: TimeInterval = 120

    private let adUnitID = "ca-app-pub-7871017136061682/1614363987"

    private var interstitial: InterstitialAd?
    private var translationCount = 0
    private var shownThisSession = 0
    private var lastShownAt: Date?

    override init() {
        super.init()
        preload()
    }

    /// Call after each successful translation; shows an ad when due.
    func translationCompleted() {
        translationCount += 1
        guard translationCount % Self.interstitialInterval == 0,
              shownThisSession < Self.maxPerSession,
              lastShownAt.map({ Date().timeIntervalSince($0) >= Self.minSecondsBetweenShows }) ?? true
        else { return }
        showIfReady()
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

    private func showIfReady() {
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
        shownThisSession += 1
        lastShownAt = Date()
        Analytics.logEvent("interstitial_shown", parameters: [
            "translation_count": translationCount,
            "shown_this_session": shownThisSession,
        ])
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
