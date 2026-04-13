import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:melody/pages/discover_page.dart';
import 'package:melody/pages/library_page.dart';

void main() {
  testWidgets('Discover page includes opacity and rotation animations', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: DiscoverPage()));

    expect(find.byType(AnimatedOpacity), findsWidgets);
    expect(find.byType(RotationTransition), findsWidgets);
  });

  testWidgets('Library page includes required animated widget types', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: LibraryPage()));

    expect(find.byType(AnimatedContainer), findsWidgets);
    expect(find.byType(AnimatedPositioned), findsWidgets);
    expect(find.byType(AnimatedDefaultTextStyle), findsWidgets);
    expect(find.byType(ScaleTransition), findsWidgets);
  });
}
