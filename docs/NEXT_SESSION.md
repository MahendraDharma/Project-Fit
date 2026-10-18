# Next session

State at the end of the last session, and what to pick up.

## State
- `main` is the branch to work on; CI (`test.yml`) is green on it.
- Tests: protocol 667, analytics 802, app 6100 (`flutter test --concurrency=1`, Flutter 3.41.6).
- iOS: `ios-sideload.yml` builds an unsigned IPA; install guide in `docs/IOS_SIDELOAD.md`.
- DB schema v59. Parity status in `docs/WHOOP_PARITY.md`.
- Commits are authored by the repository owner only; no co-author trailers.

## Manual GitHub settings (owner)
- Settings → Default branch → `main`; then delete the old `claude/...` branch.
- About: description, website (`docs/IOS_SIDELOAD.md`), topics:
  whoop, garmin, fitness, hrv, sleep-tracking, flutter, bluetooth-low-energy, local-first, health, wearables.
- Settings → Social preview → upload `docs/assets/social-preview.png`.

## Open work, in order
1. Decode WHOOP 4.0 `undecodable_rec_v25` (76-byte) records from an OpenStrap export.
2. Garmin account export: run
   `python3 -I tools/garmin_inventory/inventory.py <zip> -o garmin_report.md --json garmin_report.json`
   outside the repo, then plan the Garmin import path (FIT + Apple Health).
3. Body Battery from FIT field 227/3 in the decoder.
4. Skin temperature / SpO₂ field identification on WHOOP 4.0 (needs reference measurements).
5. "Wake when recovery is green".
6. Verify the sideloaded app on a real iPhone.

Personal health exports never go in the repository (`.gitignore` covers them).
