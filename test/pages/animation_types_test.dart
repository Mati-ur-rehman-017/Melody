import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:melody/pages/discover_page.dart';
import 'package:melody/pages/playlists_page.dart';
import 'package:melody/pages/songs_page.dart';

void main() {
  testWidgets('Discover page includes opacity and rotation animations', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: DiscoverPage()));

    expect(find.byType(AnimatedOpacity), findsWidgets);
    expect(find.byType(RotationTransition), findsWidgets);
  });

  testWidgets('Songs page includes animated widget types', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: SongsPage()));

    expect(find.byType(AnimatedBuilder), findsWidgets);
  });

  testWidgets('Playlists page renders correctly', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: PlaylistsPage()));

    expect(find.text('Playlists'), findsOneWidget);
  });
}
