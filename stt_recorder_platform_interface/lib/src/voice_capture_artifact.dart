import 'dart:typed_data';

/// Cross-platform capture result returned by `stt_recorder`.
class VoiceCaptureArtifact {
  /// Creates a capture artifact.
  const VoiceCaptureArtifact({
    required this.bytes,
    required this.fileName,
    required this.mimeType,
    this.path,
  });

  /// Creates an artifact from a method-channel payload map.
  factory VoiceCaptureArtifact.fromMap(Map<Object?, Object?> rawMap) {
    final bytes = rawMap['bytes'];
    final fileName = rawMap['fileName'];
    final mimeType = rawMap['mimeType'];
    final path = rawMap['path'];

    if (bytes is! Uint8List ||
        fileName is! String ||
        mimeType is! String ||
        (path != null && path is! String)) {
      throw Exception('stt_recorder_invalid_artifact');
    }

    return VoiceCaptureArtifact(
      bytes: bytes,
      fileName: fileName,
      mimeType: mimeType,
      path: path as String?,
    );
  }

  /// Captured audio bytes.
  final Uint8List bytes;

  /// Best-effort output filename.
  final String fileName;

  /// MIME type associated with [bytes].
  final String mimeType;

  /// Native file path when the platform provides one.
  final String? path;

  /// Converts the artifact into a method-channel payload map.
  Map<String, Object?> toMap() {
    return {
      'bytes': bytes,
      'fileName': fileName,
      'mimeType': mimeType,
      'path': path,
    };
  }
}
