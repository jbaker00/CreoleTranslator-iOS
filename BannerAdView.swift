import SwiftUI
#if canImport(GoogleMobileAds)
import GoogleMobileAds
#endif

struct BannerAdView: View {
    var body: some View {
        BannerAdRepresentable()
            .frame(height: 60)
    }
}

struct BannerAdRepresentable: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        #if canImport(GoogleMobileAds)
        let banner = BannerView(adSize: GADAdSizeBanner)
        banner.adUnitID = Secrets.admobBannerAdUnitID
        banner.rootViewController = UIApplication.shared.windows.first?.rootViewController
        banner.load(Request())
        return banner
        #else
        let label = UILabel()
        label.text = "[AdMob Banner Placeholder]"
        label.textAlignment = .center
        label.backgroundColor = .systemGray5
        return label
        #endif
    }
    func updateUIView(_ uiView: UIView, context: Context) {}
}
