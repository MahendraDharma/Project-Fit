# Next session

State at the end of the last session, and what to pick up.

## Ground rules
- Work on `main`. Push the designated session branch and `main` together.
- **Commits are authored by the repository owner only**
  (`Mahendra Dharma Putra <65089209+MahendraDharma@users.noreply.github.com>`), with no
  co-author or session trailers. The same applies to PR bodies and GitHub comments.
- The owner writes in Indonesian; reply in Indonesian.
- Personal health exports never go in the repository (`.gitignore` covers them). The owner's
  OpenStrap export lived only in the previous session's scratchpad, so ask for it again if a
  task needs real data.

## State
- CI (`test.yml`) is green on `main`. Superseded runs are cancelled only on PRs.
- Tests: protocol 670, analytics 802, app 6100 (`flutter test --concurrency=1`, Flutter 3.41.6).
- DB schema v59, `kAlgoVersion` 113. Parity status is in `docs/WHOOP_PARITY.md`.
- WHOOP 4.0 v25 records are decoded (`parseV25Waveform`). They carry one optical channel, so
  they do not unlock SpO₂ or skin temperature.
- README and `docs/IOS_SIDELOAD.md` are written for beginners, in Indonesian. They cover
  Tutorial A (iPhone only: SideInstaller → SideStore), B (Sideloadly) and C (Mac + Xcode), plus
  a troubleshooting table keyed by error message.

## iPhone release
- Release v0.12.0 has `ProjectFit.ipa`, `projectfit-v0.12.0-unsigned.ipa` and `apps.json`.
  - Fixed download link: `releases/latest/download/ProjectFit.ipa`.
  - SideStore/AltStore source: `releases/latest/download/apps.json`.
- To cut a release, run **Actions → ios-sideload → Run workflow** with `release_tag`, either
  from the UI or with the MCP `actions_run_trigger` tool. Pushing a `v*` tag also works, but
  this session's git proxy refuses tag pushes (403).

## The app runs on the owner's iPhone (Tutorial C)
Installed with Xcode and a free Personal Team (team ID in the owner's gitignored
`app/ios/Config/Signing.xcconfig`) on iOS 27.0.1. Renewal every 7 days is
`cd ~/Project-Fit/app && git pull && flutter run --release` on the owner's Mac. Sideloadly and
AltServer fail on Apple's October 2026 login block (`-80045`); see `docs/IOS_SIDELOAD.md`.

## UI redesign (done in v0.12.0: mockup v3)
The owner picked mockup v3, a WHOOP-inspired, data-dense Home (style only: no WHOOP logos,
assets or trade dress).
- Tokens live in `app/lib/ui2/theme.dart`:
  - dark: slate `#1E2328`, Barlow Condensed numerals
  - light: Bevel-like
- The tab bar is a floating pill.
- Home has:
  - a top bar with avatar, wordmark and battery, then rings with the value inside
  - vital chips and a day heart-rate card with zones
  - the recovery calibration card
  - My Day: activities, last night, tonight, health monitor
  - Dashboard rows comparing today against the 30-day mean
- The cards are in `app/lib/ui2/screens/home_vitals.dart` and are listed in the gallery.
- Indonesian (`app_id.arb`) is partial: tabs, rings, the new Home cards and some device copy.
  Other strings fall back to English.
- Not done: Sleep, Recovery, Strain and Health in the new style; the daytime stress chart that
  was offered; the full Indonesian translation.

## Rendering screens from a real export (no device needed)
The previous session did this with a throwaway widget test that was deleted afterwards. To
redo it:
1. Point `LocalDb.dbName` at a copy of the export under the sqflite-ffi databases path.
2. Load data with the screens' own loaders, e.g. `HomeData.loadForDay(repo, '<date>')`,
   `SleepData.load(repo, want: '<date>')`, `HealthData.load(repo)` and `loadMonthlyRows(repo)`.
   Here `repo = LocalRepositoryImpl(getProfileMap: ...)`.
3. Load the Manrope, Barlow Condensed, Lucide (`packages/lucide_icons_flutter/Lucide`) and
   MaterialIcons fonts.
4. Pump each screen in a `RepaintBoundary` and run `toImage` inside `tester.runAsync`.
5. Run with `TZ=Asia/Jakarta`.

## Manual GitHub settings (owner)
- Settings → Default branch → `main`, then delete the old `claude/...` branch.
- About:
  - Description: "Local-first fitness app for WHOOP & Garmin — readiness, strain, sleep and
    training load computed on your phone. Fork of OpenStrap."
  - Website: `docs/IOS_SIDELOAD.md`.
  - Topics: whoop, garmin, fitness, hrv, sleep-tracking, flutter, bluetooth-low-energy,
    local-first, health, wearables.
- Settings → Social preview → upload `docs/assets/social-preview.png`.

## Open work, in order
1. Restyle the detail screens to match the v3 Home.
2. Garmin account export (the owner requested it; up to 48 h). Run
   `python3 -I tools/garmin_inventory/inventory.py <zip> -o garmin_report.md --json garmin_report.json`
   outside the repo, then plan the Garmin import path (FIT + Apple Health).
3. Body Battery from FIT field 227/3 in the decoder.
4. Skin temperature and SpO₂ field identification on WHOOP 4.0 (needs reference measurements).
5. "Wake when recovery is green".
