# Archive Build API Key Fix

## Root Cause
Archive builds use an extremely restrictive sandbox that **blocks reading/writing source files** (`Secrets.swift`).

### Error from Build Log:
```
grep: /Users/jamesbaker/code/CreoleTranslator-iOS/Secrets.swift: Operation not permitted
```

## Solution
**Generate `GeneratedSecrets.swift` to `DERIVED_FILE_DIR`** instead of modifying source files.

### How It Works Now:
1. Pre-compile script runs BEFORE compilation
2. Reads API key from `Secrets.plist` or `GROQ_API_KEY` env var
3. **Generates NEW file**: `${DERIVED_FILE_DIR}/GeneratedSecrets.swift`
4. Compiler includes generated file automatically
5. App has API key embedded in compiled code

### Why This Works:
- ✅ **DERIVED_FILE_DIR is writable** even in Archive sandbox
- ✅ Generated files are automatically added to compilation
- ✅ No source files modified (sandbox-safe)
- ✅ Git stays clean (GeneratedSecrets.swift never committed)

## Files Changed:
- `Secrets.swift` → `Secrets.swift.template` (template only, not compiled)
- Build script now **generates** instead of **modifies**
- Removed `Secrets.swift` from Sources build phase
- Added `GeneratedSecrets.swift` to outputPaths

## Test Steps:
1. Clean build folder (⌘⇧K in Xcode)
2. Archive (Product → Archive)
3. Check build log for: `✅ Generated: .../GeneratedSecrets.swift`
4. Upload to TestFlight
5. Test app - API key should work!

## For Xcode Cloud:
Set environment variable: `GROQ_API_KEY=your_key`
Script checks env var first before Secrets.plist.
