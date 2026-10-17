import 'package:flutter_test/flutter_test.dart';
import 'package:projectfit/state/app_state.dart';
import 'package:projectfit/sync/paired_device.dart' show PairedDevice;
import 'package:projectfit/ui2/profile/devices.dart' show liveSources;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('band family falls back to the stored generation before any link', () {
    final app = AppState.forTesting();
    addTearDown(app.dispose);
    app.paired = PairedDevice('r1', 's1', generation: 'gen5');
    expect(app.device.generation, isNull);
    expect(liveSources(app).single.family, 'gen5');
  });
}
