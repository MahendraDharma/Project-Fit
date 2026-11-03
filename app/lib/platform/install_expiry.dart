// When this iPhone install stops opening.
//
// An app installed from Xcode with a free Apple ID (or through AltStore) runs
// for seven days, then iOS refuses to launch it until it is installed again
// from the Mac. The date is in the provisioning profile embedded in the app,
// read natively (`ConfigBridge.profileExpiry` in AppDelegate.swift). An App
// Store build has no such profile and never warns.
import 'dart:io' show Platform;

import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../l10n/date_text.dart';
import '../state/clock_format.dart';

class InstallExpiry {
  static const _channel = MethodChannel('projectfit/ios_config');

  /// The expiry read at launch, or null (not iOS, no profile, not read yet).
  static DateTime? value;

  /// How long before the expiry the app starts saying so.
  static const warnAhead = Duration(hours: 48);

  static Future<DateTime?> load() async {
    if (!Platform.isIOS) return null;
    try {
      final sec = await _channel.invokeMethod<num>('profileExpiry');
      value = sec == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch((sec * 1000).round());
    } catch (_) {
      // An older native side without the method: no warning, nothing else.
    }
    return value;
  }

  /// Hours left on [expiry] when it is inside [warnAhead] and still ahead,
  /// else null.
  static double? hoursLeftToWarn(DateTime? expiry, DateTime now) {
    if (expiry == null) return null;
    final left = expiry.difference(now);
    if (left.isNegative || left > warnAhead) return null;
    return left.inMinutes / 60;
  }
}

/// "on Thursday at 14:05" for the install's end, in the reader's language.
String installEndsText(AppLocalizations? l, DateTime? at) {
  if (at == null) return '';
  final day = localizedDate(at, l?.localeName ?? 'en', pattern: 'EEEE');
  return l?.installEndsAt(day, formatClockMinute(at.hour * 60 + at.minute)) ??
      'on $day at ${formatClockMinute(at.hour * 60 + at.minute)}';
}
