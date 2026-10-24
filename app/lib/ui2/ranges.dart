// Colour by range: a value's colour says which band it is in, the way Bevel
// colours a ring, a sparkline point or a calendar day by where the number
// sits rather than painting every metric one flat hue.
//
// The bands are the ones each metric already has elsewhere in the app:
// recovery's readiness bands, sleep against the night's need, strain's
// thirds of its 0-21 scale, Garmin's stress bands.
import 'package:flutter/painting.dart';

import 'theme.dart';

/// Recovery 0-100: under 34 red, under 67 yellow, then green.
Color recoveryColor(num v) => v < 34 ? C.red : (v < 67 ? C.yellow : C.green);

/// Sleep as a share of the night's need, in per cent: under 70 short, 70-85
/// normal, over 85 well slept — light to deep, as Bevel's sleep breakdown.
Color sleepColor(num pct) => pct < 70 ? C.sky : (pct < 85 ? C.indigo : C.purple);

/// Strain 0-21 in thirds: light, moderate, hard.
Color strainColor(num v) => v < 7 ? C.yellow : (v < 14 ? C.orange : C.red);

/// Stress 0-100 in Garmin's bands: rest, low, medium, high.
Color stressColor(num v) => v <= 25 ? C.teal : (v <= 50 ? C.green : (v <= 75 ? C.yellow : C.red));

/// A two-stop gradient that runs from the band below into [v]'s own band,
/// for a ring: the arc warms or cools as it fills.
List<Color> rangeGradient(Color Function(num) f, num lo, num v) => [f(lo), f(v)];

/// The colour for a metric key at a value, or null when the metric has no
/// bands of its own.
Color? rangeColorFor(String key, num v) => switch (key) {
      'readiness' || 'recovery' => recoveryColor(v),
      'strain' => strainColor(v),
      'stress' => stressColor(v),
      _ => null,
    };
