# Build-Time API Key Injection - Archive Build Solution

## Problem Summary
Archive builds use a restricted sandbox that blocks reading/writing source files during build scripts.

### Original Error:
```
grep: /Users/jamesbaker/code/CreoleTranslator-iOS/Secrets.swift: Operation not permitted
```

## ✅ Final Solution
**Generate code in `DERIVED_FILE_DIR` instead of modifying source files.**

### How It Works:
1. Pre-compile script runs BEFORE Swift compilation
2. Reads API key from `Secrets.plist` or `GROQ_API_KEY` env var
3. **Generates NEW file**: `${DERIVED_FILE_DIR}/GeneratedSecrets.swift`
4. Compiler automatically includes generated files from DERIVED_FILE_DIR
5. App has API key embedded in compiled binary

### Why This Works:
- ✅ **DERIVED_FILE_DIR is writable** even in Archive sandbox
- ✅ Generated files are automatically added to compilation
- ✅ No source files modified (sandbox-safe)
- ✅ Git stays clean (GeneratedSecrets.swift never committed)
- ✅ Works for Debug, Release, AND Archive builds

## Implementation Details

### Build Script (Pre-compile Phase):
```bash
# Located in Xcode project build phases
# Runs before "Compile Sources" phase
# Outputs: ${DERIVED_FILE_DIR}/GeneratedSecrets.swift
```

### Files Changed:
- `Secrets.swift` → Removed from project (replaced by generated file)
- `Secrets.swift.template` → Reference template (not compiled)
- Added `GeneratedSecrets.swift` to `outputPaths` in build script
- Removed `Secrets.swift` from "Compile Sources" build phase

### Generated File Structure:
```swift
import Foundation

/// Auto-generated secrets file - DO NOT EDIT
/// Generated at build time from environment variable or Secrets.plist
struct Secrets {
    static var apiKey: String? {
        let key = "actual_api_key_here"
        return key == "YOUR_API_KEY_HERE" ? nil : key
    }
}
```

## Testing Steps:
1. Clean build folder (⇧⌘K in Xcode)
2. Archive (Product → Archive)
3. Check build log for: `✅ Generated: .../GeneratedSecrets.swift`
4. Upload to TestFlight
5. Test app - API key should work!

## For Xcode Cloud:
Set environment variable in CI: `GROQ_API_KEY=your_key`
Script checks env var first before Secrets.plist.

---

**Status**: ✅ Verified Working (February 2026)  
**Method**: Code generation in DERIVED_FILE_DIR  
**Builds**: Debug ✅ | Release ✅ | Archive ✅ | TestFlight ✅
