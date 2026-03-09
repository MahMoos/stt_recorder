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

## Automated pub.dev publishing

GitHub Actions is configured for pub.dev trusted publishing with one workflow per
package:

- `publish_stt_recorder_platform_interface.yaml` with tag
  `stt_recorder_platform_interface-v{{version}}`
- `publish_stt_recorder_android.yaml` with tag
  `stt_recorder_android-v{{version}}`
- `publish_stt_recorder_ios.yaml` with tag
  `stt_recorder_ios-v{{version}}`
- `publish_stt_recorder_macos.yaml` with tag
  `stt_recorder_macos-v{{version}}`
- `publish_stt_recorder_web.yaml` with tag
  `stt_recorder_web-v{{version}}`
- `publish_stt_recorder.yaml` with tag `stt_recorder-v{{version}}`

Complete the pub.dev side once per package in the package Admin page:

1. Add trusted publishing for repository `MahMoos/stt_recorder`.
2. Select the matching workflow file for the package.
3. Set the GitHub environment to `pub.dev`.
4. Set the tag pattern to the package-specific `...-v{{version}}` value above.

After that, release by pushing the matching tag for each package version in the
documented publish order.
