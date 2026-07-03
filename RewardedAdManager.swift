import GoogleMobileAds
import UIKit

// Rewarded ad shown to unlock premium AI voices for 24 hours (see VoiceSettings).
@MainActor
class RewardedAdManager: NSObject, ObservableObject, FullScreenContentDelegate {

    // TODO: replace with a real REWARDED ad unit created in the AdMob console
    // (no rewarded unit exists yet for pub-7871017136061682). This is Google's
    // official test ID — it serves test ads and earns nothing.
    private let adUnitID = "ca-app-pub-3940256099942544/1712485313"

    @Published private(set) var isReady = false

    private var rewardedAd: RewardedAd?
    private var onReward: (() -> Void)?

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
            } catch {
                isReady = false
            }
        }
    }

    /// Shows the rewarded ad. Returns false if no ad is available
    /// (caller decides whether to grant the unlock anyway).
    @discardableResult
    func show(onReward: @escaping () -> Void) -> Bool {
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
        self.onReward = onReward
        ad.present(from: root) { [weak self] in
            self?.onReward?()
            self?.onReward = nil
        }
        return true
    }

    // MARK: FullScreenContentDelegate

    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        rewardedAd = nil
        isReady = false
        preload()
    }

    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        rewardedAd = nil
        isReady = false
        onReward = nil
        preload()
    }
}
