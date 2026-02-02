# Google AdMob Banner Ad Integration Guide

## Overview
This branch adds a Google AdMob banner ad at the bottom of the CreoleTranslator iOS app UI. The implementation is based on the working GoogleAdMobExample code.

## Files Added

1. **BannerAdView.swift** - SwiftUI banner ad view component
2. **ATTAuthorization.swift** - App Tracking Transparency permission handler

## Files Modified

1. **CreoleTranslatorApp.swift** - Added MobileAds initialization and ATT request
2. **ContentView.swift** - Added banner ad at bottom using ZStack layout
3. **Info.plist** - Added AdMob configuration keys

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

## Setup Instructions

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

4. Set version: **Up to Next Major Version: 12.12.0**

5. Click **Add Package**

6. Select **GoogleMobileAds** and click **Add Package**

### Step 2: Add New Swift Files to Xcode Project

1. In Xcode Project Navigator, right-click on the project folder
2. Select **Add Files to "CreoleTranslator"...**
3. Navigate to and select:
   - `BannerAdView.swift`
   - `ATTAuthorization.swift`
4. **Uncheck** "Copy items if needed" (files already in folder)
5. Click **Add**

### Step 3: Build and Run

1. Build: **Cmd+B**
2. Run: **Cmd+R**
3. Grant tracking permission when prompted (optional)
4. You should see a test banner ad at the bottom

## What Was Changed

### CreoleTranslatorApp.swift
- Added `import GoogleMobileAds`
- Added `@Environment(\.scenePhase)` observer
- Added `init()` with `MobileAds.shared.start()`
- Added `.onChange(of: scenePhase)` to request ATT when app becomes active

### ContentView.swift
- Changed `ZStack` to `ZStack(alignment: .bottom)`
- Added `@State private var availableWidth: CGFloat = 320`
- Changed `Spacer(minLength: 30)` to `Spacer(minLength: 80)` for banner space
- Added `GeometryReader` with `BannerAdView` at the bottom

### Info.plist
- Added `GADApplicationIdentifier` (test app ID)
- Added `NSUserTrackingUsageDescription`
- Added `SKAdNetworkItems` array with ad network identifiers

## Test Ad IDs

The code uses Google's official test IDs:
- **App ID**: `ca-app-pub-3940256099942544~1458002511`
- **Banner Unit ID**: `ca-app-pub-3940256099942544/2934735716`

These show "Test Ad" labels and are safe for development.

## Production Configuration

To use real ads in production:

1. **Get your AdMob IDs** from https://apps.admob.com/
2. **Replace in Info.plist**:
   ```xml
   <key>GADApplicationIdentifier</key>
   <string>ca-app-pub-YOUR-APP-ID~YOUR-APP-NUMBER</string>
   ```
3. **Replace in BannerAdView.swift**:
   ```swift
   let adUnitID: String = "ca-app-pub-YOUR-APP-ID/YOUR-BANNER-ID"
   ```

## Layout Details

- Banner is positioned at bottom using `ZStack(alignment: .bottom)`
- Content scrolls above the banner
- Banner height: 50pt (adaptive height may vary)
- Banner uses `.ultraThinMaterial` background for visual separation
- Banner extends to bottom edge with `.ignoresSafeArea(edges: .bottom)`
- Adaptive sizing adjusts on device rotation

## Troubleshooting

### If banner doesn't show:
1. Check that GoogleMobileAds package is added in Xcode
2. Verify both Swift files are added to the Xcode project target
3. Check console for error messages
4. Ensure device has internet connection
5. Test ads may take a few seconds to load

### If you see build errors:
- Make sure you added the Swift Package (Step 1)
- Verify the package version is 12.12.0 or higher
- Clean build folder: **Shift+Cmd+K**
- Rebuild: **Cmd+B**

## Testing

The banner will display Google test ads with "Test Ad" label. This is normal and expected during development.

To test:
1. Run on simulator or device
2. Wait a few seconds for ad to load
3. You should see "Banner loaded" in console
4. Test banner appears at bottom of screen
5. Try rotating device to verify adaptive sizing

## Git Branch

Branch name: `add-google-banner-ad`

To switch to this branch:
```bash
git checkout add-google-banner-ad
```

To merge into main (after testing):
```bash
git checkout main
git merge add-google-banner-ad
```
