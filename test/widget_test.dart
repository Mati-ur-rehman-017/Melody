import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:melody/main.dart';

void main() {
  testWidgets('App renders correctly', (WidgetTester tester) async {
    await tester.pumpWidget(const MelodyApp());
    expect(find.byType(MaterialApp), findsOneWidget);
    await tester.pump(const Duration(seconds: 3)); // clear splash screen timer
  });
}
