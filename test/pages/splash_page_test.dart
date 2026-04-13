import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:melody/pages/splash_page.dart';

void main() {
  testWidgets('SplashPage renders Melody text', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: SplashPage()));

    // Text should be present immediately after first frame
    expect(find.text('Melody'), findsOneWidget);

    // Advance time beyond splash duration without waiting for repeating ticker
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('SplashPage has black background', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: SplashPage()));

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, const Color(0xFF000000));

    // Advance time beyond splash duration without waiting for repeating ticker
    await tester.pump(const Duration(seconds: 3));
  });
}
