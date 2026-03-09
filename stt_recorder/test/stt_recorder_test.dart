import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:stt_recorder/stt_recorder.dart';
import 'package:stt_recorder_platform_interface/stt_recorder_platform_interface.dart';

class MockSttRecorderPlatform extends Mock
    with MockPlatformInterfaceMixin
    implements SttRecorderPlatform {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockSttRecorderPlatform platform;

  setUp(() {
    platform = MockSttRecorderPlatform();
    SttRecorderPlatform.instance = platform;
  });

  test('start forwards locale id to platform instance', () async {
    when(
      () => platform.startCapture(localeId: 'en-US'),
    ).thenAnswer((_) async {});

    await SttRecorder.start(localeId: 'en-US');

    verify(() => platform.startCapture(localeId: 'en-US')).called(1);
  });

  test('stop returns recording artifact from platform instance', () async {
    when(
      () => platform.stopCapture(),
    ).thenAnswer(
      (_) async => VoiceCaptureArtifact(
        bytes: Uint8List.fromList(const [1, 2, 3]),
        fileName: 'out.wav',
        mimeType: 'audio/wav',
        path: '/tmp/out.wav',
      ),
    );

    final artifact = await SttRecorder.stop();

    expect(artifact.path, '/tmp/out.wav');
    expect(artifact.fileName, 'out.wav');
    verify(() => platform.stopCapture()).called(1);
  });

  test('cancel forwards to platform instance', () async {
    when(() => platform.cancelCapture()).thenAnswer((_) async {});

    await SttRecorder.cancel();

    verify(() => platform.cancelCapture()).called(1);
  });

  test('partialTextStream returns the platform stream', () async {
    when(
      () => platform.partialTextStream(),
    ).thenAnswer((_) => Stream<String>.value('partial'));

    await expectLater(
      SttRecorder.partialTextStream(),
      emitsInOrder(const <String>['partial']),
    );
  });
}
