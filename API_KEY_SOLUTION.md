# API Key Management - Complete Guide

## Current Solution (February 2026)

The app uses **build-time code generation** to securely inject API keys without storing them in Git.

### Quick Setup

**For Development (Environment Variable):**
```bash
# In Xcode: Product → Scheme → Edit Scheme → Run → Arguments
# Add environment variable: GROQ_API_KEY = your_actual_key
```

**For Local Builds (Secrets.plist):**
```bash
cd CreoleTranslator-iOS
bash scripts/generate_secrets_plist.sh
# Follow prompts to add your API key
```

### How It Works

1. **Build script runs** before Swift compilation
2. **Checks for API key** in this order:
   - Environment variable `GROQ_API_KEY`
   - Local file `Secrets.plist`
3. **Generates code file**: `GeneratedSecrets.swift` in `DERIVED_FILE_DIR`
4. **Compiler includes** the generated file automatically
5. **App accesses key** via `Secrets.apiKey` property

### Architecture

```
┌─────────────────────────────────────────────┐
│  Build Phase: Pre-compile Script            │
│  ─────────────────────────────────────────  │
│  1. Check GROQ_API_KEY env var              │
│  2. If not found, read Secrets.plist        │
│  3. Generate GeneratedSecrets.swift         │
│  4. Write to DERIVED_FILE_DIR               │
└─────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────┐
│  Build Phase: Compile Sources                │
│  ─────────────────────────────────────────  │
│  1. Swift compiler includes generated file   │
│  2. Compiles with embedded API key           │
│  3. Creates app binary                       │
└─────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────┐
│  Runtime: App Execution                      │
│  ─────────────────────────────────────────  │
│  ContentView accesses Secrets.apiKey         │
│  GroqService uses key for API calls          │
└─────────────────────────────────────────────┘
```

### Security Benefits

✅ **Never in Git** - API keys stay local only  
✅ **Build-time only** - Key embedded during compilation  
✅ **Sandbox-safe** - DERIVED_FILE_DIR is writable in Archive builds  
✅ **CI/CD ready** - Environment variable support for automation  
✅ **GitHub verified** - Passes push protection and secret scanning

### File Reference

| File | Purpose | Tracked by Git? |
|------|---------|----------------|
| `GeneratedSecrets.swift` | Auto-generated code with key | ❌ No (ephemeral) |
| `Secrets.plist` | Local key storage | ❌ No (gitignored) |
| `Secrets.swift.template` | Code template/reference | ✅ Yes (no secrets) |
| `scripts/generate_secrets_plist.sh` | Helper script | ✅ Yes |

### For Different Environments

**Local Development:**
- Use Xcode scheme environment variable
- Quick setup, no files needed
- Key stays in Xcode settings only

**Team Development:**
- Use `Secrets.plist` (gitignored)
- Each developer creates their own
- Script helps with setup

**Xcode Cloud / CI:**
- Set `GROQ_API_KEY` environment variable
- Configure in App Store Connect or CI settings
- No plist file needed

**TestFlight / App Store:**
- Archive build uses same mechanism
- Key embedded in binary during Archive
- No runtime configuration needed

### Troubleshooting

**Build fails with "API key not found":**
- Set environment variable OR create Secrets.plist
- Run `scripts/generate_secrets_plist.sh` for plist

**Key not working at runtime:**
- Check build log for "✅ Generated: ..."
- Verify key is valid at https://console.groq.com
- Clean build folder (⇧⌘K) and rebuild

**Archive build fails:**
- Ensure build script is in Xcode project
- Check DERIVED_FILE_DIR is accessible
- Verify outputPaths includes GeneratedSecrets.swift

---

**Documentation Version**: 1.0  
**Last Updated**: February 2026  
**Status**: ✅ Production Ready & Verified
