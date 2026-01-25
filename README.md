# 🎤 Creole Translator - iOS App

A native iOS application that converts Haitian Creole speech to English text using Groq AI (Whisper + LLAMA).

## Features

- **Real-time Audio Recording** - Record Haitian Creole speech using iPhone microphone
- **AI-Powered Translation** - Uses Groq's Whisper Large V3 for transcription and LLAMA 3.3 70B for translation
- **Native iOS Experience** - Built with SwiftUI for iOS 15+
- **Privacy-Focused** - Audio processing via secure API calls, no local storage
- **Simple Setup** - Only requires a free Groq API key

## Requirements

- **iOS 15.0+**
- **Xcode 14.0+**
- **Groq API Key** (free tier available)

## Installation

### 1. Get Groq API Key

1. Visit [https://console.groq.com](https://console.groq.com)
2. Sign in with Google, GitHub, or email
3. Navigate to **API Keys** in the left menu
4. Click **"Create API Key"**
5. Give it a name (e.g., "Creole Translator iOS")
6. Copy the key

### 2. Open Project in Xcode

```bash
cd CreoleTranslator-iOS
open CreoleTranslator.xcodeproj
```

### 3. Configure API Key

Open `ContentView.swift` and add your Groq API key:

```swift
private let groqAPIKey = "your_groq_api_key_here"
```

**⚠️ Important**: For production apps, store API keys securely using:
- Keychain Services
- Environment variables
- Backend proxy (recommended)

### 4. Build and Run

1. Select your target device or simulator
2. Press ⌘R to build and run
3. Grant microphone permissions when prompted

## Project Structure

```
CreoleTranslator-iOS/
├── CreoleTranslator.xcodeproj/          # Xcode project
├── CreoleTranslator/
│   ├── CreoleTranslatorApp.swift        # App entry point
│   ├── ContentView.swift                # Main UI + logic
│   ├── GroqService.swift                # Groq API integration
│   ├── AudioRecorder.swift              # Audio recording manager
│   ├── Info.plist                       # App configuration
│   └── Assets.xcassets/                 # App icons and images
└── README.md                            # This file
```

## Usage

1. **Launch the app** on your iPhone
2. **Grant microphone permission** if prompted
3. **Tap "Start Recording"** and speak in Haitian Creole
4. **Tap "Stop Recording"** when finished
5. **View results**: Original Creole transcription and English translation

## How It Works

1. **Audio Recording**: Uses AVFoundation to capture audio in M4A format
2. **Transcription**: Sends audio to Groq's Whisper Large V3 model (supports Haitian Creole)
3. **Translation**: Uses LLAMA 3.3 70B to translate Creole text to English
4. **Display**: Shows both original and translated text in the UI

## Technologies

- **SwiftUI** - Modern declarative UI framework
- **AVFoundation** - Audio recording
- **URLSession** - HTTP networking
- **Groq Whisper Large V3** - Audio transcription (Haitian Creole support)
- **Meta LLAMA 3.3 70B** - Text translation

## API Details

### Groq Whisper API
- **Endpoint**: `https://api.groq.com/openai/v1/audio/transcriptions`
- **Model**: `whisper-large-v3`
- **Language**: Haitian Creole (ht)
- **Format**: Multipart form data with audio file

### Groq Chat API
- **Endpoint**: `https://api.groq.com/openai/v1/chat/completions`
- **Model**: `llama-3.3-70b-versatile`
- **Purpose**: Translation from Creole to English

## Troubleshooting

### Microphone Access Denied
- Go to **Settings > Privacy & Security > Microphone**
- Enable access for Creole Translator

### API Errors
```swift
// Verify your API key is correct
Error: 401 Unauthorized - Check your Groq API key
Error: 429 Too Many Requests - Rate limit exceeded, wait a moment
```

### Audio Recording Fails
- Ensure you're testing on a real device (simulator has limited audio support)
- Check microphone permissions in Settings
- Restart the app

### Build Errors
- Ensure Xcode 14.0+ is installed
- Set deployment target to iOS 15.0+
- Clean build folder (⇧⌘K) and rebuild

## Privacy & Security

- **Microphone Access**: Required only while recording
- **Data Storage**: No audio files stored locally
- **API Communication**: HTTPS encrypted
- **API Key**: Should be stored securely (not hardcoded in production)

## Best Practices for Production

1. **API Key Security**:
   ```swift
   // Use backend proxy instead of client-side API key
   // Or use Keychain for secure storage
   ```

2. **Error Handling**:
   - Show user-friendly error messages
   - Log errors for debugging
   - Implement retry logic

3. **User Experience**:
   - Add loading indicators
   - Show progress during processing
   - Cache recent translations

4. **Testing**:
   - Test with various Creole phrases
   - Test error scenarios
   - Test on different iOS versions and devices

## Future Enhancements

- [ ] Support for multiple languages
- [ ] Save translation history
- [ ] Share translations
- [ ] Offline mode with local speech recognition
- [ ] Dark mode support
- [ ] iPad optimization
- [ ] Text-to-speech for translations
- [ ] Real-time translation (streaming)

## Contributing

This is converted from a web application. Feel free to:
- Report bugs
- Suggest features
- Submit pull requests

## License

MIT License - see LICENSE file for details

## Acknowledgments

- Original web app: [CreoleToEnglish](https://github.com/jbaker00/CreoleToEnglish)
- Groq for fast Whisper and LLAMA inference
- Meta for the LLAMA model
- OpenAI for the Whisper model
