# AGENTS.md - Melody Project

This document provides high-signal guidelines for AI coding agents working in this Flutter/Dart codebase.

## Architecture & State Management

- **State Management:** Uses vanilla `ChangeNotifier` and Singleton classes (e.g., `MiniPlayerController.instance`, `CurrentColor`). Do not introduce Provider, Riverpod, or Bloc.
- **Service Layer:** All side-effects and external APIs live in `lib/services/` (e.g., `youtube_download_service.dart`, `database_service.dart`).
- **No Standalone Scripts:** Despite mentions in older docs or the README, there is NO standalone `youtube_audio_dl.dart` CLI script. Audio downloading is handled internally by `lib/services/youtube_download_service.dart` using `youtube_explode_dart`.

## Framework Quirks & Desktop Support

- **Audio:** Uses `just_audio` + `just_audio_media_kit`. Desktop playback requires `JustAudioMediaKit.ensureInitialized()` in `main.dart`.
- **Database:** Uses `sqflite` combined with `sqflite_common_ffi` for desktop support. `DatabaseService` automatically handles the `sqfliteFfiInit()` configuration.
- **Logging:** Use the `logging` package instead of `print()`. Example:
  ```dart
  log.fine('Debug details');
  log.info('Important milestones');
  log.warning('Recoverable issues');
  log.severe('Critical errors');
  ```

## Code Style & Conventions

- **Import Order:**
  1. Dart SDK imports (`dart:io`, `dart:async`)
  2. Flutter/Package imports (`package:flutter/material.dart`)
  3. Local/project imports (`package:melody/main.dart`)
  Separate each group with a blank line.
- **Type Annotations:** Always use explicit types for public APIs.
- **Visibility:** Prefix private members and State classes with an underscore.

## Verification Workflow

Before committing changes, run these in order:

```bash
dart format .          # 1. Format
flutter analyze        # 2. Lint (must have 0 issues)
flutter test           # 3. Test
```
