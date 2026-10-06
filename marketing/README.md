# App Store marketing assets

- `frame_screenshots.py cpp_spec.json` — renders the captioned 1320×2868 Custom Product Page screenshots
  (run from the repo root) from raw simulator captures in `out/shots/`.
- Raw captures come from the DEBUG screenshot mode (`ScreenshotMode.swift`):
  `xcrun simctl launch <iPhone Pro Max sim> com.jbaker.CreoleTranslator -shotScene medical -userConsentForAIDataSharing YES`
  Scenes: `medical`, `travel`, `family`, `phrasebook-<Category>`.
- `out/` is gitignored (generated PNGs).

Custom Product Pages (created 2026-10-06): Medical & Emergency, Travel to Haiti, Family & Everyday Kreyol.
In-App Event: International Creole Day 2026 (event 6819787579), card/details images in `out/creole-day-2026/`.
