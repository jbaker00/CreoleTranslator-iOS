# Backlog — Creole Translator (iOS + Android)

Unscheduled bugs, ideas and improvements. The Monday marketing report links
here and lists the top items; when a release is being prepared, look here for
small `[bug]` / `[release]` items that can ride along.

This is the single backlog for both platforms (tag `[android]` / `[ios]`
when only one is affected); Android-repo `BACKLOG.md` points here. Shipped
cross-platform features are tracked in the Android repo's `FEATURE_PARITY.md`.

**Format** — one item per line under `## Open`:

    - [P1|P2|P3] [bug|feature|security|ops|ui|copy|marketing] Title — why / what "done" looks like (added YYYY-MM-DD)

Optional tags: `[due YYYY-MM-DD]`, `[release]` (small enough to ship with the
next update), `[ios]` / `[android]` / `[proxy]`, `[blocked: reason]`.
P1 = do soon, P2 = next few releases, P3 = someday. When an item ships, move
it to `## Done` with the version or commit.

## Open

- [P1] [ops] [proxy] Replace OpenAI tts-1 before its 2027-01-06 shutdown — Creole voice playback (and My Words) use tts-1 pinned in api-proxy; the named replacement isn't usable on /v1/audio/speech yet. Done = proxy on a new model and Creole sounds at least as good. Tracked in api-proxy BACKLOG.md. (added 2026-10-17)
- [P1] [security] Add Firebase App Check (App Attest on iOS, Play Integrity on Android) — lets api-proxy verify requests really come from the app instead of a script. Ship in both apps first; the proxy enforces later (api-proxy BACKLOG.md). (added 2026-10-17)
- [P2] [android] [feature] Port HD voice plays from iOS (b85a706) — 5 free AI-voice plays/day + 10 per rewarded ad; see FEATURE_PARITY.md pending ports. (added 2026-10-17)
- [P2] [copy] Native Kreyòl review of the HD voice copy — "lekti HD", "Gade yon ti videyo pou 10 lòt lekti ak vwa HD", "Ou gen N lekti HD ki rete". (added 2026-10-17)
- [P3] [ui] [ios] HD chip crowds the "Creole Translation" card title on narrow iPhones (SE / mini) — check on device; shorten to "✨ 5" if it truncates. (added 2026-10-17)
- [P3] [feature] [proxy] Server-side HD play credits + AdMob server-side verification (SSV) — makes plays tamper-proof (today the count lives on the device; the proxy's TTS caps are the backstop). (added 2026-10-17)
- [P3] [feature] [blocked: STT quality] "Precision Listening" — rewarded-ad gate for gpt-transcribe voice input after N free/day, with Whisper or typing as the free path. Parked: Creole speech-to-text isn't good enough yet to market as "better" (1-star risk). Also a nightly-todo standing item. (added 2026-10-17)

## Done

- ~~HD voice: allow only 1 no-fill grant per day~~ — done in 3.5 (build 11), hd-voice-plays a2ec9a0; blocked attempts log `hd_grant_blocked`. (done 2026-10-19)
- 2026-10-16 OpenAI STT daily cap set to 500 (~$0.50/day) — api-proxy d749dbe
