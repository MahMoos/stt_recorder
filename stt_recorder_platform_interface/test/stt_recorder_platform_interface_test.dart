import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:stt_recorder_platform_interface/stt_recorder_platform_interface.dart';

class FakeSttRecorderPlatform extends SttRecorderPlatform
    with MockPlatformInterfaceMixin {
  @override
  Stream<String> partialTextStream() => const Stream<String>.empty();

  @override
  Future<void> startCapture({required String localeId}) async {}

  @override
  Future<VoiceCaptureArtifact> stopCapture() async {
    return VoiceCaptureArtifact(
      bytes: Uint8List.fromList(const [1, 2, 3]),
      fileName: 'voice.wav',
      mimeType: 'audio/wav',
      path: '/tmp/voice.wav',
    );
  }

  @override
  Future<void> cancelCapture() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('allows replacing platform implementation instance', () {
    final fake = FakeSttRecorderPlatform();

    SttRecorderPlatform.instance = fake;

    expect(SttRecorderPlatform.instance, same(fake));
  });
}
