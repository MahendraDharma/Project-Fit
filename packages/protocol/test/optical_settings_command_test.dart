import 'package:projectfit_protocol/projectfit_protocol.dart';
import 'package:test/test.dart';

void main() {
  test('optical GETs carry the WHOOP opcodes and refuse anything else', () {
    expect(Cmd.getLedDrive, 40);
    expect(Cmd.getTiaGain, 42);
    expect(Cmd.getBiasOffset, 44);
    final f = cmdGetOpticalSetting(5, Cmd.getTiaGain);
    expect(f, buildCommand(5, Cmd.getTiaGain, const [0x01], BandProfile.gen4));
    expect(() => cmdGetOpticalSetting(5, 41), throwsArgumentError);
  });
}
