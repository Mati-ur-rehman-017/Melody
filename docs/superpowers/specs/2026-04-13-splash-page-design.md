# Splash Page Design Spec

## Summary

Add an animated splash screen to the Melody Flutter app that displays the word "Melody" in white with a glow/pulse animation on an OLED black background, then fades into the main app after initialization completes.

---

## Goals

- Show a branded, animated splash screen on app launch
- Replace the current blank/black frame that appears during async initialization
- Minimum 2.5 seconds of splash visibility so the animation completes
- Smooth fade transition into the main app (`MainShell`)

---

## Approach

Flutter-only implementation using the already-installed `flutter_animate` package. No new dependencies. Works identically on all platforms (Android, iOS, macOS, Linux, Web).

---

## Architecture

### New file: `lib/pages/splash_page.dart`

A `StatefulWidget` responsible for:
- Rendering the animated "Melody" text centered on an OLED black background
- Running the glow/pulse animation sequence via `flutter_animate`
- Performing all async app initialization concurrently with the animation
- Navigating to `MainShell` (with a fade transition) once both the minimum duration and initialization are complete

### Modified file: `lib/main.dart`

- `main()` becomes lightweight: only `WidgetsFlutterBinding.ensureInitialized()`, `JustAudioMediaKit.ensureInitialized()`, logging setup, then `runApp()`
- All async initialization (`DatabaseService.initialize()`, `AudioService.init()`) moves into `SplashPage`
- `MelodyApp.home` changes from `MainShell()` to `SplashPage()`

---

## Animation Sequence

Total duration: ~2500ms minimum

| Phase | Timing | Description |
|-------|--------|-------------|
| Fade in | 0 – 800ms | Text fades from transparent to white (`easeOut`) |
| Glow pulse | 800 – 2200ms | Soft white glow appears and pulses 2× around the text; glow color is white at ~0.5 opacity, modulated via `shimmer` or shadow blur radius animation |
| Settle | 2200 – 2500ms | Glow fades out, clean white text remains |

After 2500ms AND initialization complete → fade-out transition to `MainShell`.

---

## Visual Specification

- **Background:** `#000000` (pure OLED black, matches `AppColors.background`)
- **Text:** "Melody"
- **Font:** Plus Jakarta Sans (the app's existing variable font)
- **Font weight:** `FontWeight.w700`
- **Font size:** 42sp
- **Text color:** `Colors.white` (the app's primary text color)
- **Glow:** white, ~0.5 opacity, soft blur (~20px radius), pulsing 2 cycles
- **No subtitle or tagline**

---

## Navigation / Transition

- From `SplashPage` to `MainShell`: `PageRouteBuilder` with `FadeTransition`, 400ms duration
- Uses `Navigator.pushReplacement` so the splash page is removed from the stack (back button does not return to splash)

---

## Initialization Work (moved from `main()` to `SplashPage`)

1. `DatabaseService.initialize()`
2. On Android/iOS: `AudioService.init()` with `MediaNotificationService` config

Both run concurrently with the animation via `Future.wait` gated by `Future.delayed(Duration(milliseconds: 2500))`.

---

## Out of Scope

- Native platform splash screen (`flutter_native_splash`) — can be added later as Approach 3
- Any subtitle, logo image, or tagline on the splash
- Light mode variant (app is dark-only)
