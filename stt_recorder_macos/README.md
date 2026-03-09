# stt_recorder_macos

macOS endorsed implementation for `stt_recorder`.

This package is consumed automatically when using the front package on macOS.

## Notes

- Captures audio through `AVAudioEngine` and writes WAV output.
- Streams partial transcript markers/text through EventChannel.
- `stop()` returns a `VoiceCaptureArtifact` with WAV bytes, filename, MIME
  type, and the native temp-file `path`.
- Requires `NSMicrophoneUsageDescription` and
  `NSSpeechRecognitionUsageDescription` in the host app `Info.plist`.
