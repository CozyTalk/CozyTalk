import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/user_status/presentation/providers/user_status_provider.dart';
import 'package:mobile/screens/choose_room_type_screen.dart';

Widget _buildScreen() {
  return ProviderScope(
    overrides: [
      onlineCountProvider.overrideWith((ref) => Stream.value(0)),
    ],
    child: const MaterialApp(home: ChooseRoomTypeScreen()),
  );
}

void main() {
  group('ChooseRoomTypeScreen', () {
    testWidgets('renders without error', (tester) async {
      await tester.pumpWidget(_buildScreen());
      expect(find.byType(ChooseRoomTypeScreen), findsOneWidget);
    });

    testWidgets('shows header title', (tester) async {
      await tester.pumpWidget(_buildScreen());
      expect(find.text('Choose your room type'), findsOneWidget);
    });

    testWidgets('shows all three room type cards', (tester) async {
      await tester.pumpWidget(_buildScreen());
      expect(find.text('1 on 1'), findsOneWidget);
      expect(find.text('Group'), findsOneWidget);
      expect(find.text('Create Group Room'), findsOneWidget);
    });

    testWidgets('Join Room button is disabled before any selection', (
      tester,
    ) async {
      await tester.pumpWidget(_buildScreen());
      final btn = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Join Room'),
      );
      expect(btn.onPressed, isNull);
    });

    testWidgets('Join Room button enables after tapping a card', (
      tester,
    ) async {
      await tester.pumpWidget(_buildScreen());
      await tester.tap(find.text('1 on 1'));
      await tester.pump();
      final btn = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Join Room'),
      );
      expect(btn.onPressed, isNotNull);
    });

    testWidgets('Join Room button enables after tapping Create Group Room', (
      tester,
    ) async {
      await tester.pumpWidget(_buildScreen());
      await tester.tap(find.text('Create Group Room'));
      await tester.pump();
      final btn = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Join Room'),
      );
      expect(btn.onPressed, isNotNull);
    });

    testWidgets('displays live online count', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            onlineCountProvider.overrideWith((ref) => Stream.value(42)),
          ],
          child: const MaterialApp(home: ChooseRoomTypeScreen()),
        ),
      );
      await tester.pump();
      expect(find.text('User online ~ 42'), findsOneWidget);
    });

    group('accessibility', () {
      testWidgets('interactive elements have semantic labels', (tester) async {
        final handle = tester.ensureSemantics();
        try {
          await tester.pumpWidget(_buildScreen());
          await tester.pumpAndSettle();
          expect(find.bySemanticsLabel('Go back'), findsOneWidget);
          // 'Close' is an IconButton tooltip inside the join-group dialog;
          // open the dialog first, then assert via byTooltip.
          await tester.tap(find.text('Group'));
          await tester.pump();
          await tester.tap(find.widgetWithText(ElevatedButton, 'Join Room'));
          await tester.pumpAndSettle();
          expect(find.byTooltip('Close'), findsOneWidget);
        } finally {
          handle.dispose();
        }
      });
    });
  });
}
