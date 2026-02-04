# AGENTS.md - Melody Project

This document provides guidelines for AI coding agents working in this Flutter/Dart codebase.

## Project Overview

- **Name**: Melody
- **Type**: Flutter cross-platform application (Android, iOS, macOS, Linux, Web)
- **Language**: Dart 3.10.1+
- **Framework**: Flutter SDK
- **Package Manager**: pub (via Flutter)

## Build, Run, and Test Commands

### Dependencies

```bash
flutter pub get              # Install dependencies
flutter pub upgrade          # Upgrade dependencies
flutter pub outdated         # Check for outdated packages
```

### Running the App

```bash
flutter run                  # Run on connected device/emulator
flutter run -d chrome        # Run on Chrome (web)
flutter run -d macos         # Run on macOS
flutter run -d linux         # Run on Linux
```

### Building

```bash
flutter build apk            # Build Android APK
flutter build ios            # Build iOS
flutter build macos          # Build macOS
flutter build linux          # Build Linux
flutter build web            # Build web
```

### Linting and Analysis

```bash
flutter analyze              # Run static analysis (linting)
dart format .                # Format all Dart files
dart format --set-exit-if-changed .  # Format check (CI mode)
dart format lib/main.dart    # Format a single file
```

### Testing

```bash
# Run all tests
flutter test

# Run a single test file
flutter test test/widget_test.dart

# Run tests matching a name pattern
flutter test --name "Counter increments"

# Run tests with coverage
flutter test --coverage

# Run tests in a specific directory
flutter test test/unit/

# Verbose test output
flutter test --reporter expanded
```

### Running Dart Scripts

```bash
# Run standalone Dart file
dart run lib/youtube_audio_dl.dart <args>
```

## Code Style Guidelines

This project uses `flutter_lints` (v6.0.0) for linting. See `analysis_options.yaml`.

### Import Order

Organize imports in this order, separated by blank lines:

```dart
// 1. Dart SDK imports
import 'dart:io';
import 'dart:async';

// 2. Flutter/Package imports
import 'package:flutter/material.dart';
import 'package:some_package/some_package.dart';

// 3. Local/project imports
import 'package:melody/main.dart';
```

### Naming Conventions

| Type | Convention | Example |
|------|------------|---------|
| Classes, Enums, Typedefs | UpperCamelCase | `MyHomePage`, `VideoState` |
| Variables, Functions, Parameters | lowerCamelCase | `videoId`, `_incrementCounter()` |
| Constants | lowerCamelCase | `defaultTimeout`, `maxRetries` |
| Private members | Leading underscore | `_counter`, `_setupLogging()` |
| Files | snake_case | `youtube_audio_dl.dart` |

### Type Annotations

- Always use explicit types for public APIs
- Use `var` or `final` for local variables when type is obvious
- Use nullable types (`?`) explicitly: `String? videoId`
- Prefer `final` for variables that won't be reassigned

```dart
// Good
final String videoId = args[0];
final List<String> items = [];
String? extractedId;

// Avoid
var videoId = args[0];  // OK for obvious types locally
dynamic data;           // Avoid dynamic when possible
```

### Documentation

- Use `///` for documentation comments (not `//`)
- Document all public APIs
- Keep comments concise and meaningful

```dart
/// Extracts video ID from various YouTube URL formats.
/// 
/// Returns `null` if the URL is invalid or video ID cannot be extracted.
String? _extractVideoId(String url) { ... }
```

### Widget Conventions

- Use `const` constructors when possible
- Use `super.key` pattern for widget keys
- Prefix private State classes with underscore

```dart
class MyWidget extends StatelessWidget {
  const MyWidget({super.key});  // Preferred key syntax
  
  @override
  Widget build(BuildContext context) {
    return const Text('Hello');  // Use const for static widgets
  }
}

class MyStateful extends StatefulWidget {
  const MyStateful({super.key, required this.title});
  final String title;  // Widget fields are always final
  
  @override
  State<MyStateful> createState() => _MyStatefulState();
}

class _MyStatefulState extends State<MyStateful> { ... }
```

### Error Handling

- Use try/catch for async operations that may fail
- Clean up resources in `finally` blocks
- Log errors with appropriate severity levels
- Rethrow exceptions when caller needs to handle them

```dart
try {
  await riskyOperation();
} catch (e, stackTrace) {
  log.severe('Operation failed: $e');
  log.fine('Stack trace: $stackTrace');
  rethrow;  // If caller needs to handle
} finally {
  cleanup();  // Always runs
}
```

### Logging

Use the `logging` package with appropriate levels:

```dart
log.fine('Debug information');      // Debug details
log.info('Important milestones');   // User-visible progress  
log.warning('Recoverable issues');  // Non-fatal problems
log.severe('Critical errors');      // Failures
```

### String Formatting

- Use string interpolation: `'Value: $variable'`
- Use braces for expressions: `'Result: ${object.property}'`
- Use raw strings for regex: `RegExp(r'^[a-z]+$')`

## Testing Conventions

### File Structure

- Test files go in `test/` directory
- Mirror the `lib/` structure
- Name test files with `_test.dart` suffix

### Widget Tests

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:melody/main.dart';

void main() {
  testWidgets('description', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    
    expect(find.text('Expected'), findsOneWidget);
    
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();
    
    expect(find.text('Updated'), findsOneWidget);
  });
}
```

### Test Naming

- Use descriptive test names that explain the expected behavior
- Group related tests with `group()`

## Project-Specific Notes

### YouTube Audio Downloader (`lib/youtube_audio_dl.dart`)

This is a standalone Dart script (not a Flutter widget) that:
- Validates YouTube URLs and extracts video IDs
- Tries multiple YouTube API client combinations for reliability
- Downloads highest-bitrate audio streams
- Handles 403 errors by falling back to alternative clients

Run with: `dart run lib/youtube_audio_dl.dart "<youtube-url>"`

## Common Issues

1. **Analysis errors**: Run `flutter analyze` before committing
2. **Format issues**: Run `dart format .` to auto-fix
3. **Missing dependencies**: Run `flutter pub get` after pulling changes
4. **Build failures**: Try `flutter clean && flutter pub get`
