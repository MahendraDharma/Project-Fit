// BAND-STATE NIGHT END — corroboration, never a source.
//
// Gen5/MG R18 body 60 bits 4-5 carry the band's own coarse envelope:
// 0 wake, 1 still, 2 sleep, 3 up ("up" only after sleep, "still" only between
// wake and sleep). No stages, lags onset, so it never creates or stages a night.
// One use: when the band reports SLEEP for the LAST time inside our window and
// then stays awake (UP/WAKE), continuously observed, for the rest of it, the
// remainder was a lie-in. Never "first UP": mid-night UP runs of 16-28 min that
// return to SLEEP are normal. STILL in the tail means re-settling — refuse.
//
// Two shapes exist for the same signal in this package: this POSITIONAL
// List<int> (1:1 with the 1 Hz arrays, -1 absent) and
// AdvancedSleepStager.detectSleep's [ts, state] pairs. Same codes.

const int kBandStateSleep = 2;
const int kBandStateStill = 1;
const int kMinBandStateCoveragePct = 80;
const int kMinBandTailCoveragePct = 95;
const int kMaxBandTailGapSec = 300;
const int kMaxBandTailStillSec = 60;
const int kMinBandOffsetTrimSec = 600;

/// The night's new end (same convention as the chosen group's `end`), or null.
///
/// [tsSec] ascending, 1:1 with [bandState]; a state outside 0..3 is ABSENT.
int? bandTrimmedOffsetSec({
  required int startSec,
  required int endSec,
  required List<int> tsSec,
  required List<int> bandState,
  int minNightSec = 3 * 3600,
}) {
  if (endSec <= startSec || tsSec.length != bandState.length) return null;
  bool known(int s) => s >= 0 && s <= 3;

  var lo = 0, hi = tsSec.length;
  while (lo < hi) {
    final mid = (lo + hi) >> 1;
    if (tsSec[mid] < startSec) {
      lo = mid + 1;
    } else {
      hi = mid;
    }
  }
  final first = lo;

  var knownSec = 0;
  int? lastSleepSec;
  int? lastCounted; // tsSec is ascending: count each distinct second once
  for (var k = first; k < tsSec.length && tsSec[k] < endSec; k++) {
    if (!known(bandState[k])) continue;
    if (tsSec[k] != lastCounted) {
      knownSec++;
      lastCounted = tsSec[k];
    }
    if (bandState[k] == kBandStateSleep) lastSleepSec = tsSec[k];
  }
  if (lastSleepSec == null) return null;
  if (knownSec * 100 < (endSec - startSec) * kMinBandStateCoveragePct) return null;

  final newEnd = lastSleepSec + 1;
  final tailSec = endSec - newEnd;
  if (tailSec < kMinBandOffsetTrimSec) return null;
  if (newEnd - startSec < minNightSec) return null;

  // The tail must be continuously observed awake: coverage, longest hole
  // (leading, internal and trailing all count) and no re-settling.
  var tailKnown = 0, stillSec = 0, maxGap = 0;
  var prevKnownTs = lastSleepSec; // the last SLEEP second itself was observed
  int? lastTailCounted, lastStillCounted;
  for (var k = first; k < tsSec.length && tsSec[k] < endSec; k++) {
    final t = tsSec[k];
    if (t < newEnd || !known(bandState[k])) continue;
    if (bandState[k] == kBandStateStill && t != lastStillCounted) {
      stillSec++;
      lastStillCounted = t;
    }
    if (t == lastTailCounted) continue;
    lastTailCounted = t;
    tailKnown++;
    final gap = t - prevKnownTs - 1;
    if (gap > maxGap) maxGap = gap;
    prevKnownTs = t;
  }
  final trailingGap = endSec - 1 - prevKnownTs;
  if (trailingGap > maxGap) maxGap = trailingGap;
  if (tailKnown * 100 < tailSec * kMinBandTailCoveragePct) return null;
  if (maxGap > kMaxBandTailGapSec) return null;
  if (stillSec > kMaxBandTailStillSec) return null;
  return newEnd;
}
