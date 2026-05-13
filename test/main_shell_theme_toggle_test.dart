import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:melody/main.dart';

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

  testWidgets('MainShell shows BottomNavigationBar with three items', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: MainShell()));
    await tester.pump();

    final navBar = tester.widget<BottomNavigationBar>(
      find.byType(BottomNavigationBar),
    );

    expect(navBar.currentIndex, 0);
    expect(navBar.items.length, 3);
    expect(navBar.items[0].label, 'Explore');
    expect(navBar.items[1].label, 'Library');
    expect(navBar.items[2].label, 'Playlists');
  });

  testWidgets('BottomNavigationBar index changes on tap', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: MainShell()));
    await tester.pump();

    await tester.tap(find.byIcon(Icons.library_music));
    await tester.pump();

    final navBar = tester.widget<BottomNavigationBar>(
      find.byType(BottomNavigationBar),
    );

    expect(navBar.currentIndex, 1);
  });
}
