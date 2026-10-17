// LOAD RATIO — acute against chronic training load.
//
// The Garmin "load ratio" idea from the published acute:chronic workload ratio
// (Hulin et al. 2014; Gabbett 2016), computed on the exponentially weighted
// loads this package already produces (`ctlAtlTsb`: ATL = 7-day, CTL = 42-day
// EWMA of daily TRIMP; the EWMA form follows Williams et al. 2017).
//
// Zones are Gabbett's (2016): below 0.8 "low", 0.8–1.3 "optimal", 1.3–1.5
// "high", above 1.5 "very high".
//
// CAVEAT, and it travels with the number: the ratio's link to injury risk is
// contested (Impellizzeri et al. 2020 show much of it can be a statistical
// artefact of coupling the two loads). It is shown as a description of how this
// week compares with the last six, never as an injury prediction.
//
// HONESTY: absent when either load is missing or the chronic load is zero (a
// ratio against nothing is not a number).

import '../types.dart';
import '../util.dart';

class LoadRatio {
  final double ratio;
  final String zone; // 'low' | 'optimal' | 'high' | 'very_high'
  const LoadRatio(this.ratio, this.zone);

  Map<String, dynamic> toJson() => {'ratio': round6(ratio), 'zone': zone};
}

/// Gabbett (2016) zone for an acute:chronic ratio.
String loadRatioZone(double ratio) => ratio < 0.8
    ? 'low'
    : ratio <= 1.3
        ? 'optimal'
        : ratio <= 1.5
            ? 'high'
            : 'very_high';

Metric<LoadRatio> loadRatio({required double? atl, required double? ctl}) {
  const inputs = ['atl', 'ctl'];
  if (atl == null || ctl == null || !atl.isFinite || !ctl.isFinite || ctl <= 0) {
    return const Metric<LoadRatio>.absent(
      tier: Tier.estimate,
      inputs_used: inputs,
      note: 'need_input:name=chronic_load',
    );
  }
  final r = atl / ctl;
  return Metric<LoadRatio>(
    value: LoadRatio(r, loadRatioZone(r)),
    confidence: 1,
    tier: Tier.estimate,
    inputs_used: inputs,
  );
}
