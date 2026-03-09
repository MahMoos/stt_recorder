import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stt_recorder_platform_interface/src/method_channel_stt_recorder.dart';
import 'package:stt_recorder_platform_interface/stt_recorder_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MethodChannelSttRecorder', () {
    late MethodChannelSttRecorder platform;
    late List<MethodCall> log;

    setUp(() {
      platform = MethodChannelSttRecorder();
      log = <MethodCall>[];

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            platform.methodChannel,
            (methodCall) async {
              log.add(methodCall);
              switch (methodCall.method) {
                case 'stopCapture':
                  return VoiceCaptureArtifact(
                    bytes: Uint8List.fromList(const [1, 2, 3]),
                    fileName: 'voice.wav',
                    mimeType: 'audio/wav',
                    path: '/tmp/voice.wav',
                  ).toMap();
                default:
                  return null;
              }
            },
          );
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(platform.methodChannel, null);
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

    test('stopCapture returns artifact from method channel', () async {
      final artifact = await platform.stopCapture();

      expect(artifact.path, '/tmp/voice.wav');
      expect(artifact.fileName, 'voice.wav');
      expect(artifact.mimeType, 'audio/wav');
      expect(artifact.bytes, orderedEquals(const <int>[1, 2, 3]));
      expect(log, <Matcher>[isMethodCall('stopCapture', arguments: null)]);
    });

    test('cancelCapture sends expected method call', () async {
      await platform.cancelCapture();

      expect(log, <Matcher>[isMethodCall('cancelCapture', arguments: null)]);
    });

    test('stopCapture throws when native side returns null', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            platform.methodChannel,
            (methodCall) async {
              if (methodCall.method == 'stopCapture') return null;
              return null;
            },
          );

      expect(platform.stopCapture, throwsException);
    });
  });
}
