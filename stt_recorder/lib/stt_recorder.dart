import 'package:stt_recorder_platform_interface/stt_recorder_platform_interface.dart';

/// Public API for starting/stopping a single-session voice capture + STT flow.
class SttRecorder {
  SttRecorder._();

  static SttRecorderPlatform get _platform =>
      SttRecorderPlatform.instance;

  /// Broadcast stream of partial recognized text emitted during capture.
  static Stream<String> partialTextStream() => _platform.partialTextStream();

  /// Starts capturing audio and speech recognition using [localeId].
  static Future<void> start({required String localeId}) {
    return _platform.startCapture(localeId: localeId);
  }

  /// Stops capture and returns the recorded capture artifact.
  static Future<VoiceCaptureArtifact> stop() {
    return _platform.stopCapture();
  }

  /// Cancels capture and discards the active recording.
  static Future<void> cancel() {
    return _platform.cancelCapture();
  }
}
