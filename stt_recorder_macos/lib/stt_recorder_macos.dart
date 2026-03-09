import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:stt_recorder_platform_interface/stt_recorder_platform_interface.dart';

/// macOS-endorsed implementation for `stt_recorder`.
class SttRecorderMacos extends SttRecorderPlatform {
  /// Method channel for start/stop/cancel invocations.
  @visibleForTesting
  final methodChannel = const MethodChannel('stt_recorder');

  /// Event channel for partial transcript updates.
  @visibleForTesting
  final eventChannel = const EventChannel('stt_recorder/events');

  /// Registers this implementation as the platform singleton.
  static void registerWith() {
    SttRecorderPlatform.instance = SttRecorderMacos();
  }

  @override
  Stream<String> partialTextStream() {
    return eventChannel
        .receiveBroadcastStream()
        .where((event) => event is String)
        .cast<String>();
  }

  @override
  Future<void> startCapture({required String localeId}) {
    return methodChannel.invokeMethod<void>('startCapture', {
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
  Future<void> cancelCapture() {
    return methodChannel.invokeMethod<void>('cancelCapture');
  }
}
