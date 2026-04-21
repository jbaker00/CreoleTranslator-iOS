# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Cross-Platform Sync

**Always read `FEATURE_PARITY.md` before making any code changes.** It lists every shared feature, the file paths in both the Android and iOS repos, key constants (models, API keys), and a checklist for adding new features. The feature parity doc lives in the Android repo at `/Users/jamesbaker/code/CreoleTranslator-android/FEATURE_PARITY.md`. The Android repo is at `/Users/jamesbaker/code/CreoleTranslator-android`.

## Architecture

Single-view SwiftUI app.

- `ContentView.swift` — main UI (voice/text input picker, result cards, direction switcher, history toggle, settings gear)
- `GroqService.swift` — Groq API calls: Whisper transcription, Llama translation, Orpheus TTS
- `OpenAITTSService.swift` — OpenAI tts-1 for Haitian Creole TTS
- `TextToSpeechManager.swift` — routes speak() calls to Groq (English), OpenAI (Creole), or AVSpeechSynthesizer fallback
- `VoiceSettings.swift` — @AppStorage-backed voice preferences (openAIVoice, groqVoice)
- `SettingsView.swift` — voice selection screen
- `AudioRecorder.swift` — AVAudioRecorder wrapper
- `TranslationHistory.swift` — Codable history model + manager
- `HistoryView.swift` — history list screen
- `BannerAdView.swift` — Google AdMob banner
- `DataPrivacyConsent.swift` + `ATTAuthorization.swift` — consent / ATT prompt
- `GeneratedSecrets.swift` — runtime API key loading from Secrets.plist

## API Keys

Keys are loaded from `Secrets.plist` (gitignored) via `GeneratedSecrets.swift`. Required keys:
- `GROQ_API_KEY`
- `OPENAI_API_KEY`
