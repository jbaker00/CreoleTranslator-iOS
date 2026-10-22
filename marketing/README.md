# App Store marketing assets

- `frame_screenshots.py cpp_spec.json` — renders the captioned 1320×2868 Custom Product Page screenshots
  (run from the repo root) from raw simulator captures in `out/shots/`.
- Raw captures come from the DEBUG screenshot mode (`ScreenshotMode.swift`):
  `xcrun simctl launch <iPhone Pro Max sim> com.jbaker.CreoleTranslator -shotScene medical` (screenshot mode skips the consent sheet)
  Scenes: `medical`, `travel`, `family`, `phrasebook-<Category>`.
- `out/` is gitignored (generated PNGs).

Custom Product Pages (created 2026-10-06): Medical & Emergency, Travel to Haiti, Family & Everyday Kreyol.
In-App Event: International Creole Day 2026 (event 6819787579), card/details images in `out/creole-day-2026/`.

Added 2026-10-22 (submitted for review the same day):
- Custom Product Pages **Learn Kreyol** and **Church & Mission Trips** — `cpp_spec_learn_church.json`, scenes `learn` / `church` /
  `phrasebook-Basics`. No search keywords yet: CPP keywords can only come from the version's keyword field, so the next version
  needs learn/church/mission added there before they can be attached.
- Product Page Optimization test **Family-first screenshots** (30% traffic) — `ppo_family_first_spec.json` (default page with the
  family shot first).
- `growth.py` + `asc_lib.py`: ASC helpers (create_cpp, screenshot_set, Asset Library upload/placement). A CPP created from a
  version template copies its screenshot sets, which can't be deleted — `screenshot_set` empties and reuses them.
