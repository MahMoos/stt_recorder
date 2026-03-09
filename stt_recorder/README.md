# stt_recorder

A federated Flutter plugin that captures audio and streams partial
speech-to-text updates from the same capture session.

## Why this package

`stt_recorder` is designed for flows where you need to:

- record audio for upload/training,
- highlight script text in real time with partial STT,
- stop once and get a final capture artifact.

## Features

- Single public API with `start`, `partialTextStream`, `stop`, and `cancel`.
- Returns a `VoiceCaptureArtifact` on `stop`.
- Streams partial transcript text during capture on Android, iOS, and macOS.
- Supports browser recording on web.
- Locale-aware start (`localeId`).
- Endorsed Android, iOS, macOS, and web implementations.

## Installation

```yaml
dependencies:
  stt_recorder: ^0.1.0
```

## Platform setup

### Android

Ensure microphone permission exists (usually merged from plugin manifest):

```xml
<uses-permission android:name="android.permission.RECORD_AUDIO" />
```

Request microphone permission before calling `start`.

### iOS

Add to `Info.plist`:

- `NSMicrophoneUsageDescription`
- `NSSpeechRecognitionUsageDescription`

Request microphone/speech permissions before calling `start`.

### macOS

Add to `macos/Runner/Info.plist`:

- `NSMicrophoneUsageDescription`
- `NSSpeechRecognitionUsageDescription`

### Web

- Run in a secure context (`https` or `localhost`).
- Call `start` from a user gesture after the browser grants microphone access.
- Web currently records audio and emits `__speech_unavailable__` so callers can
  fall back to non-STT UI behavior.

## Usage

```dart
import 'dart:async';

import 'package:stt_recorder/stt_recorder.dart';

StreamSubscription<String>? subscription;

Future<void> begin() async {
  subscription = SttRecorder.partialTextStream().listen((partial) {
    // Update your text highlighter.
    print(partial);
  });

  await SttRecorder.start(localeId: 'en-US');
}

Future<VoiceCaptureArtifact> end() async {
  final artifact = await SttRecorder.stop();
  await subscription?.cancel();
  debugPrint('Saved ${artifact.fileName} as ${artifact.mimeType}');
  debugPrint('Native path: ${artifact.path ?? '(in-memory only)'}');
  return artifact;
}

Future<void> abort() async {
  await SttRecorder.cancel();
  await subscription?.cancel();
}
```

## Event markers

The stream can emit special marker strings:

- `__speech_unavailable__`
- `__speech_error__:<code>`

Treat these as control signals (not transcript words).

On web, `__speech_unavailable__` is expected today because the implementation
records audio without browser STT transcription.

## API reference

- `SttRecorder.start({required String localeId})`
- `SttRecorder.partialTextStream()`
- `SttRecorder.stop()` -> `Future<VoiceCaptureArtifact>`
- `SttRecorder.cancel()`

## Artifact fields

`VoiceCaptureArtifact` contains:

- `bytes`: captured audio bytes
- `fileName`: best-effort output name
- `mimeType`: MIME type for upload or persistence
- `path`: optional native file path when the platform writes to disk

## Publishing notes

Before publishing:

1. Run format, tests, analyze, and `flutter pub publish --dry-run` in all
   federated packages.
2. Publish from a clean package directory without local
   `pubspec_overrides.yaml` files so validation runs against hosted versions of
   sibling packages.
3. Verify iOS podspec metadata/license are correct.
4. Validate example app on Android, iOS, macOS, and web.
5. For automated publishing, configure pub.dev trusted publishing to use
   workflow `publish_stt_recorder.yaml`, environment `pub.dev`, and tag pattern
   `stt_recorder-v{{version}}`.

## License

BSD-3-Clause (see platform package licenses where applicable).
