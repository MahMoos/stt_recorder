import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:stt_recorder_platform_interface/src/method_channel_stt_recorder.dart';
import 'package:stt_recorder_platform_interface/src/voice_capture_artifact.dart';

export 'src/voice_capture_artifact.dart';

/// Platform contract for voice capture + speech recognition.
abstract class SttRecorderPlatform extends PlatformInterface {
  /// Creates a platform interface instance.
  SttRecorderPlatform() : super(token: _token);

  static final Object _token = Object();

  static SttRecorderPlatform _instance = MethodChannelSttRecorder();

  /// The active platform implementation instance.
  static SttRecorderPlatform get instance => _instance;

  /// Sets a custom platform implementation.
  static set instance(SttRecorderPlatform instance) {
    PlatformInterface.verify(instance, _token);
    _instance = instance;
  }

  /// Broadcast stream of partial transcript text.
  Stream<String> partialTextStream();

  /// Starts capturing with the desired [localeId].
  Future<void> startCapture({required String localeId});

  /// Stops capture and returns the recorded capture artifact.
  Future<VoiceCaptureArtifact> stopCapture();

  /// Cancels capture and discards any output.
  Future<void> cancelCapture();
}
