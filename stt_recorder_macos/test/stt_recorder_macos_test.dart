import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stt_recorder_macos/stt_recorder_macos.dart';
import 'package:stt_recorder_platform_interface/stt_recorder_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SttRecorderMacos', () {
    late SttRecorderMacos platform;
    late List<MethodCall> log;

    setUp(() {
      platform = SttRecorderMacos();
      log = <MethodCall>[];

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(platform.methodChannel, (methodCall) async {
            log.add(methodCall);
            if (methodCall.method == 'stopCapture') {
              return VoiceCaptureArtifact(
                bytes: Uint8List.fromList(const [1, 2, 3]),
                fileName: 'macos.wav',
                mimeType: 'audio/wav',
                path: '/tmp/macos.wav',
              ).toMap();
            }
            return null;
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(platform.methodChannel, null);
    });

    test('registerWith sets the platform instance', () {
      SttRecorderMacos.registerWith();

      expect(
        SttRecorderPlatform.instance,
        isA<SttRecorderMacos>(),
      );
    });

    test('startCapture sends expected method call', () async {
      await platform.startCapture(localeId: 'en-US');

      expect(
        log,
        <Matcher>[
          isMethodCall(
            'startCapture',
            arguments: <String, String>{'localeId': 'en-US'},
          ),
        ],
      );
    });

    test('stopCapture returns native artifact', () async {
      final artifact = await platform.stopCapture();

      expect(artifact.path, '/tmp/macos.wav');
      expect(artifact.fileName, 'macos.wav');
      expect(log, <Matcher>[isMethodCall('stopCapture', arguments: null)]);
    });

    test('cancelCapture sends expected method call', () async {
      await platform.cancelCapture();

      expect(log, <Matcher>[isMethodCall('cancelCapture', arguments: null)]);
    });
  });
}
