import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:stt_recorder_platform_interface/stt_recorder_platform_interface.dart';
import 'package:stt_recorder_web/src/wav_encoder.dart';
import 'package:web/web.dart' as web;

const _speechUnavailableMarker = '__speech_unavailable__';
const _artifactFileName = 'voice_capture.wav';
const _artifactMimeType = 'audio/wav';
const List<String> _preferredRecorderMimeTypes = <String>[
  'audio/webm;codecs=opus',
  'audio/mp4;codecs=mp4a.40.2',
  'audio/mp4',
  'audio/webm',
];

/// Web implementation for `stt_recorder`.
///
/// This records microphone audio and emits the existing speech-unavailable
/// marker so the app can fall back to timer-based highlighting when browser
/// speech recognition is not wired in.
class SttRecorderWeb extends SttRecorderPlatform {
  /// Creates the web implementation instance.
  SttRecorderWeb();

  /// Registers the web implementation.
  static void registerWith(Registrar _) {
    SttRecorderPlatform.instance = SttRecorderWeb();
  }

  final StreamController<String> _partialTextController =
      StreamController<String>.broadcast();
  web.MediaRecorder? _mediaRecorder;
  web.MediaStream? _mediaStream;
  final List<web.Blob> _chunks = <web.Blob>[];
  String _recordingMimeType = 'audio/webm';

  @override
  Stream<String> partialTextStream() => _partialTextController.stream;

  @override
  Future<void> startCapture({required String localeId}) async {
    assert(localeId.isNotEmpty, 'localeId must not be empty');
    if (_mediaRecorder != null) {
      throw PlatformException(
        code: 'already_capturing',
        message: 'Capture already started',
      );
    }

    try {
      final constraints = web.MediaStreamConstraints(audio: true.toJS);
      final stream = await web.window.navigator.mediaDevices
          .getUserMedia(constraints)
          .toDart;
      final recorderMimeType = _preferredRecorderMimeType();
      final recorder = recorderMimeType == null
          ? web.MediaRecorder(stream)
          : web.MediaRecorder(
              stream,
              web.MediaRecorderOptions(mimeType: recorderMimeType),
            );

      _mediaStream = stream;
      _mediaRecorder = recorder;
      _chunks.clear();
      _recordingMimeType = recorder.mimeType.isNotEmpty
          ? recorder.mimeType
          : (recorderMimeType ?? 'audio/webm');

      recorder
        ..ondataavailable = ((web.Event event) {
          final blob = (event as web.BlobEvent).data;
          if (blob.size > 0) {
            _chunks.add(blob);
          }
        }).toJS
        ..start();
      _partialTextController.add(_speechUnavailableMarker);
    } on web.DOMException catch (error) {
      throw PlatformException(
        code: error.name == 'NotAllowedError'
            ? 'permission_denied'
            : 'capture_start_failed',
        message: error.message,
      );
    } on PlatformException {
      rethrow;
    } on Object catch (error) {
      throw PlatformException(
        code: 'capture_start_failed',
        message: '$error',
      );
    }
  }

  @override
  Future<VoiceCaptureArtifact> stopCapture() async {
    final recorder = _mediaRecorder;
    if (recorder == null) {
      throw PlatformException(
        code: 'not_capturing',
        message: 'No active capture session',
      );
    }

    final stopCompleter = Completer<void>();
    recorder
      ..onstop = ((web.Event _) {
        if (!stopCompleter.isCompleted) {
          stopCompleter.complete();
        }
      }).toJS
      ..stop();
    await stopCompleter.future;

    final blob = web.Blob(
      _chunks.toJS,
      web.BlobPropertyBag(type: _recordingMimeType),
    );
    final bytes = await _blobToBytes(blob);
    final wavBytes = await _convertToWav(bytes);
    await _cleanup();

    return VoiceCaptureArtifact(
      bytes: wavBytes,
      fileName: _artifactFileName,
      mimeType: _artifactMimeType,
    );
  }

  @override
  Future<void> cancelCapture() async {
    final recorder = _mediaRecorder;
    if (recorder != null && recorder.state != 'inactive') {
      recorder.stop();
    }
    await _cleanup();
  }

  Future<void> _cleanup() async {
    final recorder = _mediaRecorder;
    if (recorder != null) {
      recorder
        ..ondataavailable = null
        ..onstop = null;
    }

    final tracks = _mediaStream?.getTracks().toDart;
    if (tracks != null) {
      for (final track in tracks) {
        track.stop();
      }
    }

    _mediaRecorder = null;
    _mediaStream = null;
    _chunks.clear();
  }

  Future<Uint8List> _blobToBytes(web.Blob blob) async {
    final buffer = await blob.arrayBuffer().toDart;
    return buffer.toDart.asUint8List();
  }

  String? _preferredRecorderMimeType() {
    for (final mimeType in _preferredRecorderMimeTypes) {
      if (web.MediaRecorder.isTypeSupported(mimeType)) {
        return mimeType;
      }
    }
    return null;
  }

  Future<Uint8List> _convertToWav(Uint8List bytes) async {
    final audioContext = web.AudioContext();
    try {
      final audioBuffer = await audioContext
          .decodeAudioData(bytes.buffer.toJS)
          .toDart;
      final channels = List<Float32List>.generate(
        audioBuffer.numberOfChannels,
        (index) => audioBuffer.getChannelData(index).toDart,
        growable: false,
      );
      return encodePcm16Wav(
        channels: channels,
        sampleRate: audioBuffer.sampleRate.round(),
      );
    } on Object catch (error) {
      throw PlatformException(
        code: 'capture_stop_failed',
        message: 'Unable to convert recorded audio to WAV: $error',
      );
    } finally {
      await audioContext.close().toDart;
    }
  }
}
