import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:melody/main.dart';
import 'package:melody/theme/app_theme.dart';

void main() {
  testWidgets('MainShell shows theme toggle button', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: MainShell()));
    await tester.pump();

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Icon &&
            (widget.icon == Icons.dark_mode || widget.icon == Icons.light_mode),
      ),
      findsOneWidget,
    );
  });

  testWidgets('MainShell navigation bar color changes with theme', (
    WidgetTester tester,
  ) async {
    themeModeNotifier.value = ThemeMode.dark;
    await tester.pumpWidget(_buildThemeAwareShell());
    await tester.pump();

    final initialNavColor = _findNavigationBarColor(tester);

    themeModeNotifier.value = ThemeMode.light;
    await tester.pump();

    expect(themeModeNotifier.value, ThemeMode.light);

    final toggledNavColor = _findNavigationBarColor(tester);

    expect(toggledNavColor, isNot(equals(initialNavColor)));
  });
}

Widget _buildThemeAwareShell() {
  return ValueListenableBuilder<ThemeMode>(
    valueListenable: themeModeNotifier,
    builder: (context, themeMode, child) {
      return MaterialApp(
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: themeMode,
        home: const MainShell(),
      );
    },
  );
}

Color _findNavigationBarColor(WidgetTester tester) {
  final navigationContainer = tester.widget<Container>(
    find.byKey(const ValueKey('floating-navigation')),
  );

  final boxDecoration = navigationContainer.decoration! as BoxDecoration;
  return boxDecoration.color!;
}
