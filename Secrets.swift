import Foundation

// Helper to load AdMob Ad Unit ID from Info.plist or fallback to a test ID
struct Secrets {
    static var admobBannerAdUnitID: String {
        // Try to load from Info.plist (or use a test ad unit for dev)
        Bundle.main.object(forInfoDictionaryKey: "ADMOB_BANNER_AD_UNIT_ID") as? String ?? "ca-app-pub-3940256099942544/2934735716"
    }
}
