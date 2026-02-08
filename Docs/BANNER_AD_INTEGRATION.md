# Google AdMob Banner Ad Integration Guide

## Overview
This guide covers the Google AdMob banner ad integration in the CreoleTranslator iOS app. The implementation includes a **placeholder banner** that displays ad unit information, ready to be replaced with live ads.

## Current Status

✅ **Implemented:**
- BannerAdView.swift with placeholder UI
- ATTAuthorization.swift for App Tracking Transparency
- Info.plist configured with AdMob keys
- ContentView.swift integrated with banner at bottom
- App layout adapted for banner space

⚠️ **Not Active:**
- Google Mobile Ads SDK is not currently installed
- Placeholder shows ad unit ID instead of live ads
- To enable real ads, follow "Setup Instructions" below

## Files Included

1. **BannerAdView.swift** - SwiftUI banner ad view component (currently placeholder)
2. **ATTAuthorization.swift** - App Tracking Transparency permission handler
3. **CreoleTranslatorApp.swift** - Modified for MobileAds initialization (commented out)
4. **ContentView.swift** - Banner displayed at bottom using ZStack layout
5. **Info.plist** - Contains AdMob configuration keys

## Important API Usage

The code uses the **CORRECT Google Mobile Ads API** (matching GoogleAdMobExample):

✅ **Use these:**
- `MobileAds.shared.start()`
- `BannerView`
- `Request()`
- `currentOrientationAnchoredAdaptiveBanner()`
- `BannerViewDelegate`

❌ **NOT these (old API):**
- `GADMobileAds`
- `GADBannerView`
- `GADRequest`
- `GADCurrentOrientationAnchoredAdaptiveBanner`
- `GADBannerViewDelegate`

## Setup Instructions (To Enable Live Ads)

### Step 1: Add GoogleMobileAds Swift Package

1. Open the project in Xcode:
   ```bash
   cd /Users/jamesbaker/code/CreoleTranslator-iOS
   open CreoleTranslator.xcodeproj
   ```

2. In Xcode menu: **File → Add Package Dependencies...**

3. Enter package URL:
   ```
   https://github.com/googleads/swift-package-manager-google-mobile-ads
   ```

4. Set version: **Up to Next Major Version: 12.12.0** (or latest)

5. Click **Add Package**

6. Select **GoogleMobileAds** and click **Add Package**

### Step 2: Uncomment MobileAds Code

Open `CreoleTranslatorApp.swift` and uncomment:
```swift
import GoogleMobileAds

// In init()
MobileAds.shared.start()

// In .onChange(of: scenePhase)
if scenePhase == .active {
    ATTAuthorization.requestPermission()
}
```

### Step 3: Update BannerAdView.swift

Replace the placeholder body with a real UIViewRepresentable implementation:

```swift
import GoogleMobileAds

struct BannerAdView: UIViewRepresentable {
    var width: CGFloat
    let adUnitID: String = "ca-app-pub-3940256099942544/2934735716" // Test ID
    
    func makeUIView(context: Context) -> BannerView {
        let banner = BannerView(adSize: .currentOrientationAnchoredAdaptiveBanner())
        banner.adUnitID = adUnitID
        banner.load(Request())
        return banner
    }
    
    func updateUIView(_ uiView: BannerView, context: Context) {}
}
```

### Step 4: Build and Test

1. Build: **Cmd+B**
2. Run: **Cmd+R**
3. Grant tracking permission when prompted (optional)
4. You should see a live test banner ad at the bottom

## Current Implementation Details

### BannerAdView.swift (Placeholder Mode)
Currently displays a visual placeholder that shows:
- "Ad Banner Placeholder" text
- The ad unit ID for reference
- Proper sizing and layout constraints
- System background colors for consistency

To convert to live ads, replace the `body` property with a `UIViewRepresentable` that creates a real `BannerView` from GoogleMobileAds SDK.

### ContentView.swift Integration
- Uses `ZStack(alignment: .bottom)` for layout
- `GeometryReader` provides width to banner for adaptive sizing
- `Spacer(minLength: 80)` reserves space above banner
- Banner sits at bottom with proper safe area handling
- `@State private var availableWidth` tracks device rotation

### CreoleTranslatorApp.swift
- Contains commented-out MobileAds initialization
- Includes ATT permission request code (commented)
- Ready to activate when SDK is added

### Info.plist Configuration
Already configured with:
```xml
<key>GADApplicationIdentifier</key>
<string>ca-app-pub-3940256099942544~1458002511</string>

<key>NSUserTrackingUsageDescription</key>
<string>This app uses your data to personalize ads.</string>

<key>SKAdNetworkItems</key>
<!-- Array of ad network identifiers -->
```

## Test Ad IDs

The code uses Google's official test IDs:
- **App ID**: `ca-app-pub-3940256099942544~1458002511`
- **Banner Unit ID**: `ca-app-pub-3940256099942544/2934735716`

These show "Test Ad" labels and are safe for development.

## Production Configuration

To use real ads in production:

1. **Create AdMob Account** at https://apps.admob.com/

2. **Get Your App ID and Ad Unit IDs**:
   - Create an app in AdMob console
   - Create a banner ad unit
   - Note both IDs

3. **Replace in Info.plist**:
   ```xml
   <key>GADApplicationIdentifier</key>
   <string>ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY</string>
   ```

4. **Replace in BannerAdView.swift**:
   ```swift
   let adUnitID: String = "ca-app-pub-XXXXXXXXXXXXXXXX/ZZZZZZZZZZ"
   ```

5. **Important**: 
   - Test with test IDs first
   - Use real IDs only for production builds
   - Don't click your own ads (against AdMob policy)
   - Verify ads.txt file for App Ads (if required by AdMob)

## Layout Details

- Banner is positioned at bottom using `ZStack(alignment: .bottom)`
- Content scrolls above the banner
- Banner height: 50pt (adaptive height may vary)
- Banner uses `.ultraThinMaterial` background for visual separation
- Banner extends to bottom edge with `.ignoresSafeArea(edges: .bottom)`
- Adaptive sizing adjusts on device rotation

## Troubleshooting

### Placeholder shows instead of ads:
- GoogleMobileAds SDK not installed
- Follow "Setup Instructions" above to add package
- Uncomment MobileAds code in CreoleTranslatorApp.swift
- Update BannerAdView.swift to use real BannerView

### Build errors after adding SDK:
- Clean build folder: **Shift+Cmd+K**
- Verify package version is 12.12.0 or higher
- Check that import GoogleMobileAds is present
- Restart Xcode if needed

### Banner doesn't show after SDK setup:
1. Check console for GoogleMobileAds error messages
2. Verify internet connection
3. Ensure ad unit ID is correct
4. Test ads may take 5-10 seconds to load
5. Check device date/time is correct

### App Tracking Transparency not prompting:
- Verify NSUserTrackingUsageDescription is in Info.plist
- Check iOS version (ATT required for iOS 14.5+)
- Permission only shows once per app install
- Reset by deleting app and reinstalling

## Why Use a Placeholder?

The app includes a **placeholder banner** instead of requiring the GoogleMobileAds SDK because:

1. **Lighter Development**: SDK not needed during development of core features
2. **Flexible Testing**: Can test UI layout without live ads
3. **Optional Feature**: Developers can choose whether to enable ads
4. **No Compile Dependencies**: App builds without external package
5. **Easy Activation**: Simply add package and uncomment code when ready

The placeholder maintains proper spacing and layout, ensuring the UI looks correct whether ads are enabled or not.

## Testing

### With Placeholder (Current State):
1. Run on simulator or device
2. Banner shows "Ad Banner Placeholder" at bottom
3. Displays ad unit ID for reference
4. Layout and spacing is correct
5. Rotates properly with device orientation

### With Live Ads (After Setup):
1. Add GoogleMobileAds package
2. Uncomment initialization code
3. Update BannerAdView to use real BannerView
4. Run on simulator or device
5. Wait for ad to load (5-10 seconds)
6. Check console for "Banner loaded" message
7. Test banner appears at bottom of screen
8. Try rotating device to verify adaptive sizing
9. Test ATT prompt on first launch

## References

- **Google Mobile Ads Swift Package**: https://github.com/googleads/swift-package-manager-google-mobile-ads
- **AdMob iOS Documentation**: https://developers.google.com/admob/ios/quick-start
- **Banner Ad Guide**: https://developers.google.com/admob/ios/banner
- **App Tracking Transparency**: https://developer.apple.com/documentation/apptrackingtransparency
- **AdMob Console**: https://apps.admob.com/

---

**Status**: Placeholder Implemented ✅  
**Live Ads**: Requires GoogleMobileAds SDK 📦  
**Last Updated**: February 2026
