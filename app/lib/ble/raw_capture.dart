// A bounded recording of the band's live frames, exactly as they arrive, for
// the owner to export and study (docs/WHOOP_PARITY.md: the WHOOP app itself
// decodes none of this on the phone; its server does). Nothing here decodes
// or derives — a capture is evidence for finding the optical and temperature
// channels, not an input to any score.
//
// One file, JSON Lines: a header line (app version, band, the optics the strap
// reported, start time), then one line per frame `{"t": ms, "pt": type,
// "hex": frame}`, then a footer with the per-type counts.
import 'dart:convert';

import 'package:flutter/foundation.dart';

class RawCapture extends ChangeNotifier {
  RawCapture({required this.minutes, DateTime Function()? now})
      : _now = now ?? DateTime.now;

  /// How long the capture runs once started.
  final int minutes;
  final DateTime Function() _now;

  /// Upper bound on frames kept, so a capture left running cannot exhaust
  /// memory (~10 min of gen4 R10 + IMU + HR is well under this).
  static const int maxFrames = 200000;

  DateTime? _startedAt;
  DateTime? _endedAt;
  final List<String> _lines = [];
  final Map<int, int> _counts = {};
  Map<String, Object?> _header = const {};
  bool _truncated = false;

  DateTime? get startedAt => _startedAt;
  bool get running => _startedAt != null && _endedAt == null;
  bool get finished => _endedAt != null;
  Map<int, int> get counts => Map.unmodifiable(_counts);
  int get frames => _lines.length;

  /// Seconds left, 0 once the time is up.
  int get secondsLeft {
    final s = _startedAt;
    if (s == null) return minutes * 60;
    final left = minutes * 60 - _now().difference(s).inSeconds;
    return left < 0 ? 0 : left;
  }

  bool get timeUp => running && secondsLeft == 0;

  void start(Map<String, Object?> header) {
    _startedAt = _now();
    _header = {...header, 'started': _startedAt!.toIso8601String(), 'minutes': minutes};
    notifyListeners();
  }

  /// One live frame. Ignored outside the running window.
  void add(int pt, String hex, int? recTs) {
    if (!running) return;
    if (_lines.length >= maxFrames) {
      _truncated = true;
      return;
    }
    _counts[pt] = (_counts[pt] ?? 0) + 1;
    _lines.add(jsonEncode({
      't': _now().millisecondsSinceEpoch,
      'pt': pt,
      'rec': ?recTs,
      'hex': hex,
    }));
  }

  void stop() {
    if (!running) return;
    _endedAt = _now();
    notifyListeners();
  }

  /// The file's text.
  String toJsonl() {
    final b = StringBuffer()..writeln(jsonEncode({'kind': 'projectfit-raw-capture', 'v': 1, ..._header}));
    for (final l in _lines) {
      b.writeln(l);
    }
    b.writeln(jsonEncode({
      'kind': 'end',
      'ended': _endedAt?.toIso8601String(),
      'frames': _lines.length,
      'truncated': _truncated,
      'counts': {for (final e in _counts.entries) '0x${e.key.toRadixString(16)}': e.value},
    }));
    return b.toString();
  }

  /// `projectfit-raw-20261026-2340.jsonl`, local time.
  String get fileName {
    final t = _startedAt ?? _now();
    String two(int v) => v.toString().padLeft(2, '0');
    return 'projectfit-raw-${t.year}${two(t.month)}${two(t.day)}-${two(t.hour)}${two(t.minute)}.jsonl';
  }
}
