# Splash Page Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an animated splash screen that shows "Melody" in white with a glow/pulse animation on OLED black, runs async initialization concurrently, then fades into `MainShell`.

**Architecture:** Create `lib/pages/splash_page.dart` as a self-contained `StatefulWidget` that owns all async initialization. Modify `lib/main.dart` to make `main()` lightweight (just engine setup + `runApp()`) and point `MelodyApp.home` to `SplashPage` instead of `MainShell`.

**Tech Stack:** Flutter, `flutter_animate` ^4.5.0 (already in `pubspec.yaml`), `audio_service`, `just_audio_media_kit`, `logging`

---

## File Map

| Action | File | Responsibility |
|--------|------|----------------|
| Create | `lib/pages/splash_page.dart` | Animated splash UI, async init, navigation to MainShell |
| Modify | `lib/main.dart` | Remove async init from `main()`, change `home` to `SplashPage()` |

---

### Task 1: Create `SplashPage` widget

**Files:**
- Create: `lib/pages/splash_page.dart`

- [ ] **Step 1: Write the failing widget test**

Create `test/pages/splash_page_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:melody/pages/splash_page.dart';

void main() {
  testWidgets('SplashPage renders Melody text', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SplashPage(),
      ),
    );

    // Text should be present immediately after first frame
    expect(find.text('Melody'), findsOneWidget);
  });

  testWidgets('SplashPage has black background', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SplashPage(),
      ),
    );

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, const Color(0xFF000000));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
flutter test test/pages/splash_page_test.dart --reporter expanded
```

Expected: FAIL with `'package:melody/pages/splash_page.dart': No such file`

- [ ] **Step 3: Create `lib/pages/splash_page.dart`**

```dart
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../main.dart' show mediaNotificationService;
import '../services/database_service.dart';
import '../services/media_notification_service.dart';
import '../theme/app_theme.dart';

/// Animated splash screen shown on app launch.
///
/// Displays "Melody" with a glow/pulse animation while async initialization
/// runs concurrently. Navigates to [MainShell] once both the minimum
/// display duration (2500ms) and initialization are complete.
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    _runSplashSequence();
  }

  Future<void> _runSplashSequence() async {
    // Run initialization and minimum display duration concurrently
    await Future.wait([
      _initialize(),
      Future.delayed(const Duration(milliseconds: 2500)),
    ]);

    if (!mounted) return;
    _navigateToMain();
  }

  Future<void> _initialize() async {
    await DatabaseService.instance.initialize();

    if (Platform.isAndroid || Platform.isIOS) {
      try {
        debugPrint('[INFO] Initializing AudioService...');
        mediaNotificationService = await AudioService.init(
          builder: () => MediaNotificationService(),
          config: const AudioServiceConfig(
            androidNotificationChannelId: 'com.melody.app.audio',
            androidNotificationChannelName: 'Audio Playback',
            androidNotificationOngoing: true,
            androidStopForegroundOnPause: true,
          ),
        ).timeout(const Duration(seconds: 10));
        debugPrint('[INFO] AudioService initialized successfully');
      } catch (e, stack) {
        debugPrint('[ERROR] Failed to initialize AudioService: $e');
        debugPrint('[ERROR] Stack: $stack');
      }
    }
  }

  void _navigateToMain() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const _MainShellPlaceholder(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: const _GlowText(),
      ),
    );
  }
}

/// The "Melody" text with the three-phase glow/pulse animation.
class _GlowText extends StatelessWidget {
  const _GlowText();

  @override
  Widget build(BuildContext context) {
    return Text(
      'Melody',
      style: const TextStyle(
        fontFamily: AppTypography.fontFamily,
        fontWeight: FontWeight.w700,
        fontSize: 42,
        color: Colors.white,
      ),
    )
        // Phase 1: fade in (0–800ms)
        .animate()
        .fadeIn(duration: 800.ms, curve: Curves.easeOut)
        // Phase 2: glow shimmer pulse ×2 (800ms–2200ms)
        .shimmer(
          delay: 800.ms,
          duration: 700.ms,
          color: Colors.white.withAlpha(128),
        )
        .shimmer(
          delay: 1450.ms,
          duration: 700.ms,
          color: Colors.white.withAlpha(128),
        )
        // Phase 3: settle — slight fade on glow to clean white (implicit via shimmer end)
        .then(delay: 2200.ms);
  }
}

// Temporary placeholder — replaced in Task 2 after main.dart is updated.
// This import avoids a circular dependency during this task.
class _MainShellPlaceholder extends StatelessWidget {
  const _MainShellPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(backgroundColor: Color(0xFF000000));
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

```bash
flutter test test/pages/splash_page_test.dart --reporter expanded
```

Expected: PASS — both tests green.

- [ ] **Step 5: Run static analysis**

```bash
flutter analyze lib/pages/splash_page.dart
```

Expected: No issues.

- [ ] **Step 6: Commit**

```bash
git add lib/pages/splash_page.dart test/pages/splash_page_test.dart
git commit -m "feat: add SplashPage with glow/pulse animation"
```

---

### Task 2: Wire `SplashPage` into `main.dart` and remove `_MainShellPlaceholder`

**Files:**
- Modify: `lib/main.dart`
- Modify: `lib/pages/splash_page.dart` (remove `_MainShellPlaceholder`, fix navigation target)

- [ ] **Step 1: Update `main()` in `lib/main.dart` to remove async initialization**

Replace the entire `main()` function (lines 17–46) with:

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  JustAudioMediaKit.ensureInitialized();

  _setupLogging();

  runApp(const MelodyApp());
}
```

Remove the now-unused import at line 1 (`import 'dart:io';`) since `Platform` is no longer used in `main.dart`.

- [ ] **Step 2: Change `MelodyApp.home` from `MainShell` to `SplashPage`**

In `lib/main.dart`, update the `MelodyApp.build` method:

```dart
import 'pages/splash_page.dart';

// In MelodyApp.build:
@override
Widget build(BuildContext context) {
  return MaterialApp(
    title: 'Melody',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.theme,
    home: const SplashPage(),
  );
}
```

Remove the now-unused `import 'pages/discover_page.dart';` and `import 'pages/library_page.dart';` from `main.dart` only if `MainShell` stays in `main.dart` (it does — those imports are still needed by `MainShell`). Keep them.

- [ ] **Step 3: Fix `_navigateToMain` in `splash_page.dart` to push `MainShell`**

In `lib/pages/splash_page.dart`, replace the `_MainShellPlaceholder` import and usage with the real `MainShell`:

Add import at top of file:
```dart
import '../main.dart' show MainShell, mediaNotificationService;
```

Update `_navigateToMain`:
```dart
void _navigateToMain() {
  Navigator.of(context).pushReplacement(
    PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) =>
          const MainShell(),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: animation, child: child);
      },
      transitionDuration: const Duration(milliseconds: 400),
    ),
  );
}
```

Remove the `_MainShellPlaceholder` class entirely from `splash_page.dart`.

- [ ] **Step 4: Run static analysis on both modified files**

```bash
flutter analyze lib/main.dart lib/pages/splash_page.dart
```

Expected: No issues.

- [ ] **Step 5: Run all tests**

```bash
flutter test --reporter expanded
```

Expected: All tests pass (including the existing `test/widget_test.dart` and the new splash tests).

- [ ] **Step 6: Commit**

```bash
git add lib/main.dart lib/pages/splash_page.dart
git commit -m "feat: wire SplashPage as app entry point, move init out of main()"
```

---

### Task 3: Manual verification

- [ ] **Step 1: Build and run on Linux (or available platform)**

```bash
flutter run -d linux
```

Verify visually:
- App launches to OLED black screen
- "Melody" text fades in over ~800ms
- White glow shimmer pulses across text twice (~800ms–2200ms)
- Text settles to clean white
- After ~2.5 seconds total, app fades to the Explore/Library main shell
- Back button does NOT return to splash screen

- [ ] **Step 2: Run full test suite one final time**

```bash
flutter test --reporter expanded
```

Expected: All tests pass.

- [ ] **Step 3: Commit if any fixes were needed during manual verification**

```bash
git add -A
git commit -m "fix: splash page manual verification adjustments"
```

Only run this step if fixes were needed. Skip if no changes.
