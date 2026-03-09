# stt_recorder_platform_interface

Platform contract for the `stt_recorder` federated plugin.

## Exposed contract

Implementations must support:

- `partialTextStream()`
- `startCapture({required String localeId})`
- `stopCapture()` returning a `VoiceCaptureArtifact`
- `cancelCapture()`

## Artifact contract

`VoiceCaptureArtifact` is the cross-platform result returned by `stopCapture()`.
Implementations must provide:

- `bytes`
- `fileName`
- `mimeType`

`path` is optional and should only be set when the platform has a stable native
file path to expose.

## Implementing a new platform

1. Create a package that depends on this package.
2. Extend `SttRecorderPlatform`.
3. Set your implementation with
   `SttRecorderPlatform.instance = YourImplementation()`.
4. Register it as an endorsed implementation in the front package.
