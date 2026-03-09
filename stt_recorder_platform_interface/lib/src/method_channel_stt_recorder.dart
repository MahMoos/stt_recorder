import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart';
import 'package:stt_recorder_platform_interface/stt_recorder_platform_interface.dart';

/// Method-channel implementation of [SttRecorderPlatform].
class MethodChannelSttRecorder extends SttRecorderPlatform {
  /// Method channel for start/stop/cancel calls.
  @visibleForTesting
  final methodChannel = const MethodChannel('stt_recorder');

  /// Event channel for partial transcript events.
  @visibleForTesting
  final eventChannel = const EventChannel('stt_recorder/events');

  @override
  Stream<String> partialTextStream() {
    return eventChannel
        .receiveBroadcastStream()
        .where((event) => event is String)
        .cast<String>();
  }

  @override
  Future<void> startCapture({required String localeId}) async {
    await methodChannel.invokeMethod<void>('startCapture', {
      'localeId': localeId,
    });
  }

  @override
  Future<VoiceCaptureArtifact> stopCapture() async {
    final result = await methodChannel.invokeMethod<Object?>('stopCapture');
    if (result is! Map<Object?, Object?>) {
      throw Exception('stt_recorder_stop_failed');
    }
    return VoiceCaptureArtifact.fromMap(result);
  }

  @override
  Future<void> cancelCapture() async {
    await methodChannel.invokeMethod<void>('cancelCapture');
  }
}
