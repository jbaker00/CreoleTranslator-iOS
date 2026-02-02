# Quick Start Guide - Creole Translator iOS

## 📱 What You Have

A complete iOS app written in Swift that converts Haitian Creole speech to English using Groq AI.

## 🚀 How to Get Started

### Step 1: Open in Xcode
```bash
cd CreoleTranslator-iOS
open CreoleTranslator.xcodeproj
```

### Step 2: Add Your API Key
1. In Xcode, open `ContentView.swift`
2. Find line 18: `private let groqAPIKey = "YOUR_GROQ_API_KEY_HERE"`
3. Replace with your actual Groq API key from https://console.groq.com

### Step 3: Build and Run
1. Select your iPhone or simulator from the device menu
2. Press ⌘R (or click the Play button)
3. Grant microphone permission when prompted

### Step 4: Test It Out
1. Tap "Start Recording"
2. Speak in Haitian Creole
3. Tap "Stop Recording"
4. See the transcription and translation!

## 📁 Project Structure

```
CreoleTranslator-iOS/
├── CreoleTranslator.xcodeproj/     # Xcode project file
├── CreoleTranslatorApp.swift       # App entry point
├── ContentView.swift               # Main UI (⚠️ Add API key here!)
├── AudioRecorder.swift             # Audio recording logic
├── GroqService.swift               # Groq API integration
├── Info.plist                      # Microphone permissions
├── Assets.xcassets/                # App icons
└── README.md                       # Full documentation
```

## 🔑 Get Your Groq API Key

1. Go to https://console.groq.com
2. Sign in (it's free!)
3. Go to "API Keys" in the left sidebar
4. Click "Create API Key"
5. Copy the key and paste it in ContentView.swift

## 💡 What This App Does

1. **Records audio** using your iPhone microphone
2. **Transcribes** Haitian Creole speech using Whisper Large V3
3. **Translates** to English using LLAMA 3.3 70B
4. **Displays** both the original and translated text

## ⚙️ Tech Stack

- **Language**: Swift 5.0
- **UI Framework**: SwiftUI
- **iOS Version**: 15.0+
- **AI Service**: Groq (Whisper + LLAMA)
- **Audio**: AVFoundation

## 🎯 Key Features

✅ Native iOS app (no web view)  
✅ SwiftUI modern UI  
✅ Real-time audio recording  
✅ Direct API integration  
✅ No backend required  
✅ Clean, simple interface  
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

For production use, consider:
1. Store API key securely (not hardcoded)
2. Add translation history
3. Implement offline mode
4. Add more language pairs
5. Publish to App Store

See full README.md for detailed documentation!
