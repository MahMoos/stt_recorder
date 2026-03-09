import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stt_recorder_android/stt_recorder_android.dart';
import 'package:stt_recorder_platform_interface/stt_recorder_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SttRecorderAndroid', () {
    late SttRecorderAndroid platform;
    late List<MethodCall> log;

    setUp(() {
      platform = SttRecorderAndroid();
      log = <MethodCall>[];

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(platform.methodChannel, (
            methodCall,
          ) async {
            log.add(methodCall);
            if (methodCall.method == 'stopCapture') {
              return VoiceCaptureArtifact(
                bytes: Uint8List.fromList(const [1, 2, 3]),
                fileName: 'android.wav',
                mimeType: 'audio/wav',
                path: '/tmp/android.wav',
              ).toMap();
            }
            return null;
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(platform.methodChannel, null);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockStreamHandler(platform.eventChannel, null);
    });

    test('registerWith sets the platform instance', () {
      SttRecorderAndroid.registerWith();

      expect(
        SttRecorderPlatform.instance,
        isA<SttRecorderAndroid>(),
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

      expect(artifact.path, '/tmp/android.wav');
      expect(artifact.fileName, 'android.wav');
      expect(log, <Matcher>[isMethodCall('stopCapture', arguments: null)]);
    });

    test('stopCapture throws when native response is invalid', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(platform.methodChannel, (methodCall) async {
            log.add(methodCall);
            if (methodCall.method == 'stopCapture') {
              return 'invalid';
            }
            return null;
          });

      await expectLater(platform.stopCapture(), throwsException);
      expect(log, <Matcher>[isMethodCall('stopCapture', arguments: null)]);
    });

    test('cancelCapture sends expected method call', () async {
      await platform.cancelCapture();

      expect(log, <Matcher>[isMethodCall('cancelCapture', arguments: null)]);
    });

    test('partialTextStream filters non-string events', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockStreamHandler(
            platform.eventChannel,
            MockStreamHandler.inline(
              onListen: (_, events) {
                events
                  ..success('partial')
                  ..success(42)
                  ..success('final')
                  ..endOfStream();
              },
            ),
          );

      await expectLater(
        platform.partialTextStream().toList(),
        completion(<String>['partial', 'final']),
      );
    });
  });
}
