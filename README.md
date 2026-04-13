# Melody

Melody is a cross-platform Flutter music app focused on YouTube audio discovery, download, and playback with a polished, animated UI.

## Features

- Search YouTube tracks and download audio
- Real-time download progress in search results
- Library management for downloaded songs and playlists
- Mini-player + full player experience
- Offline playback from local storage
- Theme toggle with persisted preference
- Cached trending content and artwork support

## Tech Stack

- Flutter + Dart 3.10+
- `youtube_explode_dart` for YouTube metadata and streams
- `just_audio` + `audio_service` for playback and media controls
- `sqflite` for local persistence
- `shared_preferences` for lightweight settings

## Requirements

- Flutter SDK (stable)
- Dart SDK `^3.10.1` (managed by Flutter)
- Platform toolchains for your target (Android/iOS/macOS/Linux/Web)

## Quick Start

```bash
flutter pub get
flutter run
```

## Common Commands

### Run

```bash
flutter run
flutter run -d chrome
flutter run -d macos
flutter run -d linux
```

### Test

```bash
flutter test
flutter test test/main_shell_theme_toggle_test.dart
```

### Analyze + Format

```bash
flutter analyze
dart format .
```

### Build

```bash
flutter build apk
flutter build ios
flutter build macos
flutter build linux
flutter build web
```

## Project Structure

```text
lib/
  controller/      # UI and playback state controllers
  models/          # Domain models (track, playlist, trending song)
  pages/           # Main screens (discover, library, player, splash)
  services/        # Download, DB, audio, theme, and external services
  theme/           # Design system and theme definitions
  widgets/         # Reusable UI components
test/
  pages/           # Page-level tests
  *.dart           # Widget and integration-style UI tests
```

## Notes

- Main app entrypoint: `lib/main.dart`
- Standalone downloader script: `lib/youtube_audio_dl.dart`
  - Run with: `dart run lib/youtube_audio_dl.dart "<youtube-url>"`

## Troubleshooting

- Dependency issues: `flutter pub get`
- Formatting/lint issues: `dart format .` then `flutter analyze`
- Build cache issues: `flutter clean && flutter pub get`

## License

This project is currently private/unpublished (`publish_to: none`). Add a license file if you plan to distribute it.
