# API Key Management for Archive Builds

## The Problem
Xcode's Archive build process uses an extremely restrictive sandbox that blocks:
- Reading external files (even with inputPaths declared)
- Writing to most locations
- Executing external scripts
- All file operations we tried

## The Solution
Use `Info.plist` with git `assume-unchanged` flag:

### How It Works
1. **Info.plist.template** - Committed to git with placeholder
2. **Info.plist** - Has real API key, marked as `assume-unchanged`
3. Git ignores local changes to Info.plist
4. Your real key stays on your machine only

### Setup (Already Done)
```bash
# Generate Info.plist from template with your key
sed 's/__REPLACE_WITH_YOUR_API_KEY__/YOUR_ACTUAL_KEY/' Info.plist.template > Info.plist

# Tell git to ignore changes
git update-index --assume-unchanged Info.plist
```

### For Xcode Cloud
Set `GROQ_API_KEY` as environment variable in App Store Connect.
The app checks environment variable first (Secrets.swift priority #1).

### Verification
```bash
# Check git won't track Info.plist changes
git status Info.plist
# Should show: nothing to commit

# Verify key is in Info.plist
grep GROQ_API_KEY Info.plist
# Should show your real key
```

### If You Need to Update Info.plist Structure
```bash
# Temporarily allow tracking
git update-index --no-assume-unchanged Info.plist

# Make your changes
# ... edit Info.plist ...

# Update template
cp Info.plist Info.plist.template
# Replace real key with placeholder in template
sed -i '' 's/YOUR_API_KEY_HERE[a-zA-Z0-9]*/

__REPLACE_WITH_YOUR_API_KEY__/' Info.plist.template

# Mark as ignored again
git update-index --assume-unchanged Info.plist

# Commit template
git add Info.plist.template
git commit -m "Update Info.plist.template"
```

### Why This Works
- ✅ Archive builds can read Info.plist (always allowed)
- ✅ Git won't push your real key (assume-unchanged)
- ✅ Template in git shows structure without secrets
- ✅ Simple, no complex scripts
- ✅ Works for Debug, Release, AND Archive builds

### Security Notes
- Info.plist with real key stays LOCAL ONLY
- Template pushed to GitHub has placeholder
- Xcode Cloud uses environment variable
- Your API key never leaves your machine
