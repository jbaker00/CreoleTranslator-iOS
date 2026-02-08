# Quick Start Guide - Creole Translator iOS

## 📱 What You Have

A complete iOS app written in Swift that converts Haitian Creole speech to English using Groq AI, with translation history and optional ad support.

## 🚀 How to Get Started

### Step 1: Open in Xcode
```bash
cd CreoleTranslator-iOS
open CreoleTranslator.xcodeproj
```

### Step 2: Configure Your API Key

**Method 1: Environment Variable (Quick & Easy)**
1. In Xcode: Product → Scheme → Edit Scheme...
2. Select "Run" → "Arguments" tab
3. Add environment variable:
   - Name: `GROQ_API_KEY`
   - Value: Your API key from https://console.groq.com
4. Enable the checkbox

**Method 2: Secrets.plist (Persistent)**
1. Run: `bash scripts/generate_secrets_plist.sh`
2. Edit `Secrets.plist` and add your key
3. Build will auto-inject the key

### Step 3: Build and Run
1. Select your iPhone or simulator from the device menu
2. Press ⌘R (or click the Play button)
3. Grant microphone permission when prompted

### Step 4: Test It Out
1. Tap "Start Recording" 🎙️
2. Speak in Haitian Creole
3. Tap "Stop Recording" ⏹️
4. See the transcription (🇭🇹) and translation (🇺🇸)!
5. Tap the history button (🔄) to view past translations

## 📁 Project Structure

```
CreoleTranslator-iOS/
├── CreoleTranslator.xcodeproj/     # Xcode project file
├── CreoleTranslatorApp.swift       # App entry point with AdMob init
├── ContentView.swift               # Main UI with history integration
├── AudioRecorder.swift             # Audio recording logic
├── GroqService.swift               # Groq API integration
├── TranslationHistory.swift        # History data model
├── HistoryView.swift               # History UI
├── BannerAdView.swift              # Ad banner (placeholder)
├── GeneratedSecrets.swift          # Auto-generated API key file
├── Info.plist                      # App config & permissions
├── Secrets.plist                   # Local API key (gitignored)
├── scripts/                        # Build scripts
└── Docs/                           # Full documentation
```

## 🔑 Get Your Groq API Key

1. Go to https://console.groq.com
2. Sign in (it's free!)
3. Go to "API Keys" in the left sidebar
4. Click "Create API Key"
5. Copy the key and paste it in ContentView.swift

## 💡 What This App Does

1. **Records audio** using your iPhone microphone with AVFoundation
2. **Transcribes** Haitian Creole speech using Groq's Whisper Large V3
3. **Translates** to English using LLAMA 3.3 70B
4. **Displays** both the original and translated text with flag emojis
5. **Saves history** of all translations with timestamps
6. **Shows ads** (optional banner at bottom for monetization)

## ⚙️ Tech Stack

- **Language**: Swift 5.0
- **UI Framework**: SwiftUI
- **iOS Version**: 15.0+
- **AI Service**: Groq (Whisper + LLAMA)
- **Audio**: AVFoundation

## 🎯 Key Features

✅ Native iOS app (no web view)  
✅ SwiftUI modern UI with animations  
✅ Real-time audio recording with M4A format  
✅ Direct API integration (no backend)  
✅ Translation history with persistence  
✅ Dark mode adaptive UI  
✅ AdMob banner integration (optional)  
✅ Secure API key management  
✅ Supports Haitian Creole natively  

## 🐛 Troubleshooting

**Can't build?**
- Make sure you have Xcode 14.0 or later
- Check that deployment target is set to iOS 15.0

**Microphone not working?**
- Test on a real device (not simulator)
- Check Settings > Privacy > Microphone
- Make sure you granted permission when prompted

**API errors?**
- Verify your API key is correct in ContentView.swift
- Check your internet connection
- Visit https://console.groq.com to verify your account

## 📝 Next Steps

**Current Features (✅ Already Implemented):**
- Translation history with local storage
- Dark mode support
- Secure API key injection at build time
- Banner ad placeholder

**Future Enhancements:**
1. Enable real AdMob ads (see BANNER_AD_INTEGRATION.md)
2. Implement offline mode with local speech recognition
3. Add more language pairs beyond Haitian Creole
4. Add iCloud sync for history across devices
5. Publish to App Store

See full **Docs/README.md** for detailed documentation!
