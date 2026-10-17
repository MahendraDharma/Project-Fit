# Proposal: a `vendor_staged` sleep source

Status: implemented (kAlgoVersion 108, schema 58).

## What was built

The main-sleep window precedence in `lib/compute/substrate.dart` is now:

```
user override (manual / confirmed / rejected) > vendor_staged > auto (van Hees) > auto_fallback (HR-led) > none
```

- Storage: `vendor_sleep_epoch` (device, night onset, epoch start/end, stage,
  source, decoded_at). Stages are stored in our `stages4` words. `observation`
  stays scalars only and is still never read by a derivation
  (`test/observation_isolation_test.dart`).
- Write path: the Oura adapter turns each `data` hypnogram page into epochs
  through one mapping function, `ouraStage4`. A code with no stage drops that
  page, and the hole then fails the gate for the whole night. The per-stage
  minutes are still banked as vendor scalars.
- Plausibility gate (`lib/compute/vendor_sleep.dart`): a night is used only
  when its epochs are contiguous and non-overlapping, it is 3 to 14 h long, it
  sits inside the substrate and before it was decoded, no one stage holds 90%
  or more of it, and it overlaps at least half of our own detected or HR-led
  window. A failing night stays stored and unused, and the reason is logged.
- Staging: a vendor night uses our forced-window segmentation for the window
  and confidence, with every stage figure taken from the vendor epochs.
  Analytics is unchanged.
- Provenance: the day bundle carries `sleep_source = vendor_staged`, and the
  Sleep screen shows "Staged by your ring" on the window and the hypnogram.

## Why a hypnogram and not other vendor numbers

A sleep score or readiness is a composite with no method we can describe. A
hypnogram is a window plus a per-epoch stage label, the same shape as our own
`stages4`, so it can be cross-checked against our staging night by night.
Agreement is not validation; only PSG validates either.

## Out of scope

- A general "trust vendor numbers" rule.
- Ownership changes. Which device owns a signal stays with
  `_resolveOwnership` (`signal_priority`, primary device by default).
