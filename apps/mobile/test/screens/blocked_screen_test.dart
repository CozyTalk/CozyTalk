import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/screens/blocked_screen.dart';

void main() {
  group('BlockedScreen', () {
    testWidgets('renders without error', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: BlockedScreen()));
      expect(find.byType(BlockedScreen), findsOneWidget);
    });

    testWidgets('shows Blocked title in header', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: BlockedScreen()));
      expect(find.text('Blocked'), findsOneWidget);
    });

    testWidgets('shows blocked user count', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: BlockedScreen()));
      expect(find.text('2/5'), findsOneWidget);
    });

    testWidgets('shows an Unblock button for each blocked user', (
      tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: BlockedScreen()));
      expect(find.text('Unblock'), findsNWidgets(2));
    });

    testWidgets('shows the blocked users list', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: BlockedScreen()));
      expect(find.byType(ListView), findsOneWidget);
    });

    testWidgets('tapping Unblock shows confirmation dialog', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: BlockedScreen()));
      await tester.tap(find.text('Unblock').first);
      await tester.pumpAndSettle();
      expect(find.text('Unblock "somchai99"'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });
  });
}
