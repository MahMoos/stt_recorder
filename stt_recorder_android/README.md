# stt_recorder_android

Android endorsed implementation for `stt_recorder`.

This package is consumed automatically when using the front package on Android.

## Notes

- Captures PCM16 mono audio and writes WAV output.
- Streams partial transcript markers/text through EventChannel.
- `stop()` returns a `VoiceCaptureArtifact` with WAV bytes, filename, MIME
  type, and the native temp-file `path`.
- Requires `RECORD_AUDIO` permission.
