## 0.1.0+1

- Initial federated release.
- Added start/stop/cancel capture API.
- Added partial text stream API.
- Added Android, iOS, macOS, and web endorsed implementations.
- Made `stop()` return `VoiceCaptureArtifact` with capture bytes and metadata.
- Documented web fallback behavior where recording works and
  `__speech_unavailable__` is emitted for non-STT flows.
