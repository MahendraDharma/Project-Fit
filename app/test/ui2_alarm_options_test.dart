// The Alarm screen lets the alarm be tried before a real wake, and offers a
// normal and a heavy-sleeper level for both the band and the phone.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projectfit/ui2/profile/alarm.dart';
import 'package:projectfit/ui2/ui2.dart';

Widget _host(Widget child) =>
    MaterialApp(theme: buildTheme(Brightness.light), home: child);

void main() {
  testWidgets('try it now, and pick a level for the band and the phone', (t) async {
    var tried = 0, previews = 0;
    bool? strong, loud;
    t.view.physicalSize = const Size(1170, 5000);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    await t.pumpWidget(_host(AlarmScreenView(
      connected: true,
      phoneSound: true,
      onTest: () async {
        tried++;
        return (band: true, phone: true);
      },
      onVibrationStrong: (v) async => strong = v,
      onSoundLoud: (v) async => loud = v,
      onPreviewSound: () async {
        previews++;
        return true;
      },
    )));

    // No alarm armed yet, and it can still be tried.
    await t.tap(find.text('Try the alarm now'));
    await t.pump();
    expect(tried, 1);

    await t.tap(find.text('Band vibration'));
    await t.pumpAndSettle();
    await t.tap(find.text('Super strong').last);
    await t.pumpAndSettle();
    expect(strong, isTrue);

    await t.tap(find.text('Phone sound'));
    await t.pumpAndSettle();
    await t.tap(find.text('Super loud').last);
    await t.pumpAndSettle();
    expect(loud, isTrue);

    await t.tap(find.text('Hear the sound'));
    expect(previews, 1);
    await t.pump(const Duration(seconds: 5));
  });

  testWidgets('the sound level only shows when the phone rings', (t) async {
    t.view.physicalSize = const Size(1170, 5000);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    await t.pumpWidget(_host(const AlarmScreenView(connected: true)));
    expect(find.text('Band vibration'), findsOneWidget);
    expect(find.text('Phone sound'), findsNothing);
    expect(find.text('Hear the sound'), findsNothing);
  });
}
