// Firebase is not configured for ProjectFit yet.
//
// The file this replaces pointed at the upstream project's Firebase app, so a
// ProjectFit build would have sent its (opt-in) telemetry there. Until you
// run `flutterfire configure` against your own Firebase project,
// [DefaultFirebaseOptions.currentPlatform] throws: main() catches it and every
// telemetry call is skipped, since each one checks FirebaseBridge.isInitialized.
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform => throw UnsupportedError(
        'Firebase is not configured for ProjectFit. '
        'Run `flutterfire configure` with your own Firebase project.',
      );
}
