# stt_recorder (Federated Workspace)

This directory contains the federated plugin workspace:

- `stt_recorder` (app-facing package)
- `stt_recorder_platform_interface`
- `stt_recorder_android`
- `stt_recorder_ios`
- `stt_recorder_macos`
- `stt_recorder_web`

## Local development

```sh
# Front package
cd stt_recorder
flutter pub get
flutter test
flutter analyze

# Platform interface
cd ../stt_recorder_platform_interface
dart pub get
dart test
dart analyze

# Android implementation
cd ../stt_recorder_android
flutter pub get
flutter test
dart analyze

# iOS implementation
cd ../stt_recorder_ios
flutter pub get
flutter test
dart analyze

# macOS implementation
cd ../stt_recorder_macos
flutter pub get
flutter test
dart analyze

# Web implementation
cd ../stt_recorder_web
flutter pub get
flutter test
dart analyze
```

## Supported platforms

- Android via `stt_recorder_android`
- iOS via `stt_recorder_ios`
- macOS via `stt_recorder_macos`
- Web via `stt_recorder_web`

## Current public contract

- `start(localeId: ...)` starts a single capture session
- `partialTextStream()` emits transcript updates and control markers
- `stop()` returns a `VoiceCaptureArtifact`
  - `bytes`
  - `fileName`
  - `mimeType`
  - optional `path` on native file-backed platforms
- `cancel()` discards the active capture session

## Release checklist

1. Update versions/changelog in all impacted packages.
2. Run analysis, tests, and `flutter pub publish --dry-run` for all packages.
3. Publish from clean package directories without local `pubspec_overrides.yaml`
   files to avoid dependency-override validation hints.
4. Validate example app behavior on Android, iOS, macOS, and web.
5. Publish in order:
   - `stt_recorder_platform_interface`
   - `stt_recorder_android`
   - `stt_recorder_ios`
   - `stt_recorder_macos`
   - `stt_recorder_web`
   - `stt_recorder`
