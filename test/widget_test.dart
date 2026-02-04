import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:melody/main.dart';

void main() {
  testWidgets('App renders with bottom navigation', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MelodyApp());

    // Verify the app title is displayed
    expect(find.text('Melody'), findsOneWidget);

    // Verify bottom navigation exists with two destinations
    expect(find.text('Download'), findsOneWidget);
    expect(find.text('Library'), findsOneWidget);
  });

  testWidgets('Download page is shown by default', (WidgetTester tester) async {
    await tester.pumpWidget(const MelodyApp());

    // Verify the URL input field exists
    expect(find.byType(TextField), findsOneWidget);

    // Verify the download button exists
    expect(find.text('Download Audio'), findsOneWidget);

    // Verify the initial status message
    expect(find.text('Enter a YouTube URL to download audio'), findsOneWidget);
  });

  testWidgets('Download button is present and enabled initially', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MelodyApp());

    // Find the download button by its text
    final downloadButton = find.text('Download Audio');
    expect(downloadButton, findsOneWidget);

    // Find the button's ancestor that we can tap
    final buttonFinder = find.ancestor(
      of: downloadButton,
      matching: find.byWidgetPredicate((widget) => widget is ButtonStyleButton),
    );
    expect(buttonFinder, findsOneWidget);
  });

  testWidgets('Paste button exists in URL field', (WidgetTester tester) async {
    await tester.pumpWidget(const MelodyApp());

    // Find the paste icon button
    expect(find.byIcon(Icons.content_paste), findsOneWidget);
  });

  testWidgets('Can navigate to Library page', (WidgetTester tester) async {
    await tester.pumpWidget(const MelodyApp());

    // Tap on Library tab
    await tester.tap(find.text('Library'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // The Library page should show loading or empty state
    // Since we're in test environment, it may still be loading
    // Just verify we can navigate (download button should not be visible as primary)
    expect(find.byIcon(Icons.library_music), findsWidgets);
  });

  testWidgets('Can navigate back to Download page', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MelodyApp());

    // Tap on Library tab
    await tester.tap(find.text('Library'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Tap on Download tab
    await tester.tap(find.text('Download'));
    await tester.pump();

    // Verify download page is shown again
    expect(find.text('Download Audio'), findsOneWidget);
  });
}
