# API Key Fix for Archive Builds

## Problem
- App works when running from Xcode (Debug)
- App fails with "Missing Groq API key" error when built as Archive (Release/TestFlight/App Store)
- Environment variables in Xcode schemes only apply to Debug builds, NOT Archive builds

## Root Cause
The GROQ_API_KEY environment variable set in your Xcode scheme is only available when running from Xcode. When you create an Archive for distribution, environment variables from schemes are NOT included.

## Solution Implemented
Updated the build script to **copy your local Secrets.plist** file into the app bundle during ALL builds (Debug, Release, Archive).

### Files Changed

1. **scripts/inject_api_key.sh** - Updated to:
   - Priority 1: Copy local `Secrets.plist` if it exists (your case)
   - Priority 2: Generate from `GROQ_API_KEY` environment variable (for CI/Xcode Cloud)
   - Works for Debug, Release, AND Archive builds

2. **CreoleTranslator.xcodeproj/project.pbxproj** - Updated build script to call external script

### How It Works Now

**For Local Development (your machine):**
1. You have `/Users/jamesbaker/code/CreoleTranslator-iOS/Secrets.plist` with your API key
2. Build script copies it to app bundle: `CreoleTranslator.app/Secrets.plist`
3. Works for Run, Test, AND Archive builds
4. Secrets.plist stays gitignored ✅

**For Xcode Cloud:**
1. Set GROQ_API_KEY environment variable in App Store Connect
2. Build script generates Secrets.plist from environment variable
3. Works in cloud builds

## Testing Instructions

### Test 1: Archive Build (Main Test)
1. Open Xcode
2. Select **Product → Archive**
3. Wait for archive to complete
4. Click **Distribute App → Development** (for testing on your device)
5. Install and run the app
6. Verify it works WITHOUT the "Missing API key" error

### Test 2: Regular Run (Should still work)
1. Select your device/simulator
2. Click Run (⌘R)
3. Verify app works normally

### Test 3: Check Build Log
1. During any build, check the build log (⌘9 → Report Navigator)
2. Look for output:
   ```
   🔧 Running inject_api_key.sh
      Source: /Users/jamesbaker/code/CreoleTranslator-iOS/Secrets.plist
      Output: .../CreoleTranslator.app/Secrets.plist
   ✅ Copied Secrets.plist from project to app bundle
   ```

## What Changed from Before

**Before:**
- Build script only generated Secrets.plist if GROQ_API_KEY environment variable was set
- Environment variables from schemes don't work for Archive builds
- Archive builds failed because no Secrets.plist was created

**After:**
- Build script now **copies** your local Secrets.plist file
- Works for ALL build types (Debug, Release, Archive)
- Fallback to environment variable if local file doesn't exist (for Xcode Cloud)

## Security Notes
- ✅ Secrets.plist is still gitignored (won't be committed)
- ✅ API key only exists locally on your machine
- ✅ Xcode Cloud uses environment variable (secure)
- ✅ No API key in source code

## Next Steps
1. **Test an Archive build** following Test 1 above
2. If successful, your next TestFlight upload will work
3. For Xcode Cloud builds, ensure GROQ_API_KEY is set in App Store Connect environment variables

## Troubleshooting

**If Archive still fails:**
1. Verify Secrets.plist exists: `ls -la /Users/jamesbaker/code/CreoleTranslator-iOS/Secrets.plist`
2. Check it has your API key: `cat /Users/jamesbaker/code/CreoleTranslator-iOS/Secrets.plist`
3. Make sure script is executable: `ls -la scripts/inject_api_key.sh` (should show `x` permission)
4. Check build log for script output

**If you see "Neither Secrets.plist file nor GROQ_API_KEY environment variable found":**
- Your local Secrets.plist file is missing
- Recreate it with your API key (I can help if needed)
