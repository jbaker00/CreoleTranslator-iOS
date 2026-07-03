import GoogleMobileAds
import UIKit

// Rewarded ad shown to unlock premium AI voices for 24 hours (see VoiceSettings).
@MainActor
class RewardedAdManager: NSObject, ObservableObject, FullScreenContentDelegate {

#if DEBUG
    // Google sample rewarded unit — new production units can take hours to
    // start serving, so debug builds use this to always get a fill.
    private let adUnitID = "ca-app-pub-3940256099942544/1712485313"
#else
    private let adUnitID = "ca-app-pub-7871017136061682/5611090338"
#endif

    @Published private(set) var isReady = false

    private var rewardedAd: RewardedAd?
    private var onReward: (() -> Void)?
    private var onDismiss: (() -> Void)?
    private var onPresentFailure: (() -> Void)?

    override init() {
        super.init()
        preload()
    }

    func preload() {
        Task {
            do {
                rewardedAd = try await RewardedAd.load(with: adUnitID, request: Request())
                rewardedAd?.fullScreenContentDelegate = self
                isReady = true
                print("[RewardedAd] loaded and ready")
            } catch {
                isReady = false
                print("[RewardedAd] failed to load: \(error.localizedDescription)")
            }
        }
    }

    /// Shows the rewarded ad. Returns false if no ad is available
    /// (caller decides whether to grant the unlock anyway).
    /// `onDismiss` fires after the ad closes — safe point to present UI.
    /// `onPresentFailure` fires if the SDK could not put the ad on screen.
    @discardableResult
    func show(onReward: @escaping () -> Void,
              onDismiss: (() -> Void)? = nil,
              onPresentFailure: (() -> Void)? = nil) -> Bool {
        guard let ad = rewardedAd,
              let root = UIApplication.shared
                .connectedScenes
                .compactMap({ ($0 as? UIWindowScene)?.windows.first(where: { $0.isKeyWindow }) })
                .first?
                .rootViewController
        else {
            preload()
            return false
        }
        // Present from the top-most VC — the root is usually already
        // presenting the settings sheet, and presenting from a VC that is
        // already presenting fails silently.
        var top = root
        while let presented = top.presentedViewController { top = presented }
        self.onReward = onReward
        self.onDismiss = onDismiss
        self.onPresentFailure = onPresentFailure
        // One-shot: drop our reference so a re-entrant show() can't
        // re-present the same ad and overwrite the callbacks above.
        rewardedAd = nil
        isReady = false
        ad.present(from: top) { [weak self] in
            self?.onReward?()
            self?.onReward = nil
        }
        return true
    }

    // MARK: FullScreenContentDelegate

    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        rewardedAd = nil
        isReady = false
        onDismiss?()
        clearCallbacks()
        preload()
    }

    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        print("[RewardedAd] failed to present: \(error.localizedDescription)")
        rewardedAd = nil
        isReady = false
        onPresentFailure?()
        clearCallbacks()
        preload()
    }

    private func clearCallbacks() {
        onReward = nil
        onDismiss = nil
        onPresentFailure = nil
    }
}
