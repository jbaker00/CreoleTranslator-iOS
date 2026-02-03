# GitHub Copilot Instructions for CreoleTranslator-iOS

## Project Overview

**Creole Translator** is a native iOS application that converts Haitian Creole speech to English text using AI. The app leverages Groq's API for both speech-to-text transcription (Whisper Large V3) and translation (LLAMA 3.3 70B).

### Key Features
- Real-time audio recording using AVFoundation
- AI-powered transcription and translation via Groq API
- Modern SwiftUI interface
- Privacy-focused (no local storage of audio)
- Supports iOS 15.0+

## Technical Stack

### Languages & Frameworks
- **Language**: Swift 5.0
- **UI Framework**: SwiftUI
- **Minimum iOS**: iOS 15.0
- **IDE**: Xcode 14.0+

### Core Technologies
- **AVFoundation**: Audio recording and session management
- **URLSession**: HTTP networking for API calls
- **Combine**: For reactive state management
- **SwiftUI**: Declarative UI framework

### External Services
- **Groq API**: 
  - Whisper Large V3 for Haitian Creole transcription
  - LLAMA 3.3 70B for translation to English

## Architecture

### File Structure
```
CreoleTranslator-iOS/
├── CreoleTranslatorApp.swift    # App entry point with @main
├── ContentView.swift             # Main UI and user interactions
├── AudioRecorder.swift           # Audio recording manager (ObservableObject)
├── GroqService.swift             # API integration service
├── Secrets.swift                 # Secure API key management
├── BannerAdView.swift            # Ad integration (optional)
├── ATTAuthorization.swift        # App Tracking Transparency
├── Info.plist                    # App configuration & permissions
├── Assets.xcassets/              # App icons and images
├── scripts/                      # Build and setup scripts
│   ├── generate_secrets_plist.sh
│   ├── inject_api_key.sh
│   └── generate_app_icons.sh
└── Docs/                         # Documentation
    ├── README.md
    ├── QUICKSTART.md
    └── CONVERSION-SUMMARY.md
```

### Key Components

#### 1. ContentView.swift
- Main user interface using SwiftUI
- Manages app state (@State, @StateObject)
- Handles user interactions (record, stop, display results)
- Shows loading states and error messages
- Adaptive UI for light/dark mode

#### 2. AudioRecorder.swift
- `ObservableObject` class managing AVAudioRecorder
- Handles microphone permissions
- Records audio in M4A (AAC) format
- Publishes recording state changes
- Manages audio session interruptions

#### 3. GroqService.swift
- Service layer for Groq API interactions
- Two main functions:
  - `transcribeAudio()`: Converts audio to Haitian Creole text
  - `translateText()`: Translates Creole to English
- Error handling with custom `GroqError` enum
- Multipart form data for audio upload

#### 4. Secrets.swift
- Centralized API key management
- Multiple loading strategies (priority order):
  1. Environment variable `GROQ_API_KEY`
  2. Secrets.plist (gitignored)
  3. Info.plist (not recommended for production)

## Development Workflow

### Setup
1. Clone the repository
2. Open `CreoleTranslator.xcodeproj` in Xcode
3. Configure API key using one of these methods:
   - **Recommended**: Set `GROQ_API_KEY` in Xcode scheme (Product → Scheme → Edit Scheme → Run → Arguments → Environment Variables)
   - **Alternative**: Run `scripts/generate_secrets_plist.sh` to create `Secrets.plist`
4. Select target device or simulator
5. Build and run (⌘R)

### Building
- Standard Xcode build process (⌘B)
- No external dependencies or package managers required
- Build scripts in `scripts/` directory for automation

### Testing
- Test on real iOS devices for microphone access
- Simulator has limited audio support
- Verify microphone permissions in Settings

### API Key Management
- **Never commit API keys to the repository**
- `Secrets.plist` is gitignored
- Use environment variables for development
- For production, implement backend proxy or secure keychain storage

## Coding Standards & Conventions

### Swift Style
- Use SwiftUI best practices
- Follow Swift naming conventions (camelCase for variables/functions, PascalCase for types)
- Use `@State` for local view state
- Use `@StateObject` for observable objects owned by the view
- Use `@Published` in ObservableObject classes for reactive updates

### Code Organization
- Keep UI logic in views (ContentView.swift)
- Business logic in separate service files (GroqService.swift)
- Platform-specific code in dedicated files (AudioRecorder.swift)
- Use Swift's error handling with custom error types

### Comments
- Use `//` for single-line comments
- Header comments with file purpose
- Document complex algorithms or business logic
- Minimal inline comments (code should be self-documenting)

### SwiftUI Patterns
- Use declarative syntax
- Prefer composition over inheritance
- Use ViewModifiers for reusable styling
- Handle async operations with Task { }
- Update UI on main thread with `@MainActor` or `DispatchQueue.main.async`

## Security Best Practices

### API Key Security
- Never hardcode API keys in source files
- Use environment variables for development
- Implement secure storage (Keychain) for production
- Consider backend proxy for API calls in production apps

### Permissions
- Request microphone permission only when needed
- Handle permission denied gracefully
- Inform users why permissions are needed
- Check permission status before recording

### Privacy
- No local storage of recorded audio
- Audio sent to API via HTTPS
- No user data persistence without consent
- Follow Apple's privacy guidelines

## Common Tasks

### Adding a New Feature
1. Create or modify the relevant Swift file
2. Follow existing patterns (e.g., ObservableObject for state)
3. Update UI in ContentView or create new SwiftUI View
4. Test on real device if hardware-dependent
5. Update documentation if user-facing

### Modifying API Integration
- Edit `GroqService.swift`
- Maintain error handling patterns
- Update `GroqError` enum if adding new error cases
- Test with various network conditions

### UI Changes
- Edit `ContentView.swift` or create new View files
- Use existing color scheme (gradient background)
- Ensure dark mode compatibility
- Test on different iOS devices and screen sizes

### Updating Dependencies
- This project has minimal dependencies
- For Swift Package Manager: File → Add Packages
- Update `Package.resolved` if dependencies change
- Verify compatibility with iOS 15.0+

## Troubleshooting

### Build Issues
- Clean build folder: ⇧⌘K
- Check Xcode version (requires 14.0+)
- Verify deployment target is iOS 15.0+
- Restart Xcode if issues persist

### Runtime Issues
- **Microphone not working**: Test on real device, check permissions
- **API errors**: Verify API key is correctly configured
- **Recording fails**: Check AVAudioSession setup and permissions
- **UI not updating**: Ensure state updates on main thread

### Common Errors
- "Invalid API key": Check Secrets.swift is loading key correctly
- "Permission denied": Grant microphone access in Settings
- "Recording failed": Verify device has working microphone

## Testing Guidelines

### Manual Testing
1. Launch app on real iOS device
2. Grant microphone permission
3. Test recording flow:
   - Start recording
   - Speak in Haitian Creole
   - Stop recording
   - Verify transcription appears
   - Verify English translation appears
4. Test error scenarios:
   - No internet connection
   - Invalid API key
   - Permission denied

### Edge Cases to Consider
- Long audio recordings (>1 minute)
- Poor network conditions
- Background/foreground transitions
- Audio interruptions (phone calls, alarms)
- Low storage space

## Documentation

### Where to Find Information
- **Quick Start**: `Docs/QUICKSTART.md`
- **Full Documentation**: `Docs/README.md`
- **Conversion History**: `Docs/CONVERSION-SUMMARY.md`
- **In-code docs**: Header comments in each Swift file

### Updating Documentation
- Keep README.md in sync with code changes
- Update QUICKSTART.md for setup changes
- Document breaking changes
- Include examples for new features

## Additional Context

### Project History
- Converted from a web application (Node.js + Express)
- Original web app: [CreoleToEnglish](https://github.com/jbaker00/CreoleToEnglish)
- iOS version uses direct API integration (no backend needed)
- Simplified to single provider (Groq) for iOS

### Design Decisions
- **SwiftUI over UIKit**: Modern, declarative approach
- **Direct API calls**: No backend server required
- **M4A format**: Native iOS audio format, better compression than WebM
- **Groq only**: Simplified from multi-provider web app

### Future Enhancements
Potential features to consider:
- Translation history with local storage
- Support for additional languages
- Offline mode with local speech recognition
- Text-to-speech for translations
- Share functionality
- iPad optimization with split view
- Real-time streaming translation

## Important Notes for AI Assistants

1. **API Key Handling**: Always use `Secrets.apiKey` - never hardcode keys
2. **Audio Format**: Use M4A (AAC), not WebM or WAV
3. **Permissions**: Always check and handle microphone permissions
4. **Threading**: UI updates must be on main thread
5. **Error Handling**: Use Swift's Result type or custom error enums
6. **State Management**: Use SwiftUI's property wrappers correctly
7. **Testing**: Prefer testing on real devices for audio features
8. **Privacy**: Follow Apple's App Store privacy requirements
9. **Compatibility**: Maintain iOS 15.0+ support
10. **Code Style**: Match existing Swift conventions in the codebase
