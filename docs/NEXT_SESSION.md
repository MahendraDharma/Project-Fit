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
- Release v0.11.3 has `ProjectFit.ipa`, `projectfit-v0.11.3-unsigned.ipa` and `apps.json`.
  - Fixed download link: `releases/latest/download/ProjectFit.ipa`.
  - SideStore/AltStore source: `releases/latest/download/apps.json`.
- To cut a release, run **Actions → ios-sideload → Run workflow** with `release_tag`, either
  from the UI or with the MCP `actions_run_trigger` tool. Pushing a `v*` tag also works, but
  this session's git proxy refuses tag pushes (403).

## The app is NOT on the owner's iPhone yet
The owner's devices are an iPhone on iOS 27.0.1, a Mac, a WHOOP 4.0 and a Garmin Forerunner 55.

Every sideload attempt so far failed:
- **Sideloadly 0.71 (Mac):**
  - Fake Anisette gave `-20970`, then "Apple's login server refused".
  - Remote anisette is Patreon-only.
- **AltServer (Mac):**
  - First failed with `could not retrieve anisette data value "machineID"`.
  - After updating it failed with `-80045`, Apple's October 2026 block on sideload-tool logins.
- **SideInstaller (iPhone):**
  - Blocked at "Wi-Fi required". Its first pairing needs a Wi-Fi interface; another phone's
    hotspot works.
  - Not yet tried with a Windows-ADI anisette server, e.g. "jkcoxson (Windows ADI)".
- **Xcode (Tutorial C):**
  - Not tried. The owner is on mobile data and Xcode costs about 5–14 GB.
  - Signing needs only `app/ios/Config/Signing.xcconfig` (gitignored), containing
    `APPLE_DEVELOPMENT_TEAM = <TEAMID>`.

Next step is the owner's choice: SideInstaller on a borrowed hotspot with Windows-ADI
anisette, or Xcode once on Wi-Fi. Advise stopping after any `-80045`, since repeated failed
logins can lock the Apple ID.

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
1. Get the app onto the owner's iPhone (see above). Update `docs/IOS_SIDELOAD.md` with what
   actually worked.
2. Garmin account export (the owner requested it; up to 48 h). Run
   `python3 -I tools/garmin_inventory/inventory.py <zip> -o garmin_report.md --json garmin_report.json`
   outside the repo, then plan the Garmin import path (FIT + Apple Health).
3. Body Battery from FIT field 227/3 in the decoder.
4. Skin temperature and SpO₂ field identification on WHOOP 4.0 (needs reference measurements).
5. "Wake when recovery is green".
