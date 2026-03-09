# stt_recorder_web

Web endorsed implementation for `stt_recorder`.

This package is consumed automatically when using the front package on web.

## Notes

- Captures microphone audio with `MediaRecorder`.
- Normalizes browser-native recordings to a WAV `VoiceCaptureArtifact` for
  upload compatibility.
- Emits `__speech_unavailable__` so callers can fall back to non-STT UI when
  browser speech recognition is unavailable.
- Requires a secure browser context such as `https` or `localhost`.
