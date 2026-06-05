import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/shared/friend_message_popup.dart';

Widget _app({required Widget home}) => MaterialApp(home: home);

Future<void> _showPopup(
  WidgetTester tester, {
  String friendName = 'Alice',
  String message = 'Hey there!',
  VoidCallback? onTap,
  Duration duration = const Duration(seconds: 3),
}) async {
  await tester.pumpWidget(
    _app(
      home: Builder(
        builder: (ctx) => ElevatedButton(
          onPressed: () => showFriendMessagePopup(
            ctx,
            friendName: friendName,
            message: message,
            onTap: onTap,
            duration: duration,
          ),
          child: const Text('Show'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Show'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
}

Future<void> _drain(
  WidgetTester tester, {
  Duration extra = const Duration(seconds: 4),
}) async {
  await tester.pump(extra);
  await tester.pumpAndSettle();
}

void main() {
  group('showFriendMessagePopup', () {
    testWidgets('renders friend name', (tester) async {
      await _showPopup(tester, friendName: 'Alice');

      expect(find.text('Alice'), findsOneWidget);

      await _drain(tester);
    });

    testWidgets('renders message text', (tester) async {
      await _showPopup(tester, message: 'Hey there!');

      expect(find.text('Hey there!'), findsOneWidget);

      await _drain(tester);
    });

    testWidgets('renders avatar placeholder icon', (tester) async {
      await _showPopup(tester);

      expect(find.byIcon(Icons.person), findsOneWidget);

      await _drain(tester);
    });

    testWidgets('renders chevron_right trailing icon', (tester) async {
      await _showPopup(tester);

      expect(find.byIcon(Icons.chevron_right), findsOneWidget);

      await _drain(tester);
    });

    testWidgets('renders with very long friend name without overflow', (
      tester,
    ) async {
      await _showPopup(tester, friendName: 'A' * 200);

      expect(find.byType(Text), findsWidgets);

      await _drain(tester);
    });

    testWidgets('message text uses maxLines 1 with ellipsis', (tester) async {
      await _showPopup(tester, message: 'M' * 500);

      final textWidgets = tester.widgetList<Text>(find.byType(Text));
      expect(textWidgets.any((t) => t.maxLines == 1), isTrue);

      await _drain(tester);
    });

    testWidgets('tapping banner fires onTap callback once', (tester) async {
      var tapCount = 0;
      await _showPopup(tester, onTap: () => tapCount++);

      await tester.tap(find.text('Alice'));
      await tester.pumpAndSettle();
      await _drain(tester);

      expect(tapCount, 1);
    });

    testWidgets('tapping banner dismisses it', (tester) async {
      await _showPopup(tester, friendName: 'Alice');

      await tester.tap(find.text('Alice'));
      await tester.pumpAndSettle();

      expect(find.text('Alice'), findsNothing);

      await _drain(tester);
    });

    testWidgets('tapping banner with null onTap does not throw', (
      tester,
    ) async {
      await _showPopup(tester, onTap: null);

      await tester.tap(find.text('Hey there!'));
      await tester.pumpAndSettle();

      // No exception thrown and banner has dismissed cleanly.
      await _drain(tester);
    });

    testWidgets('banner still visible just before duration elapses', (
      tester,
    ) async {
      const testDuration = Duration(seconds: 2);
      await _showPopup(tester, duration: testDuration);

      await tester.pump(const Duration(milliseconds: 1800));
      expect(find.text('Hey there!'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
    });

    testWidgets('banner auto-dismisses after the specified duration', (
      tester,
    ) async {
      const testDuration = Duration(seconds: 2);
      await _showPopup(tester, duration: testDuration);

      await tester.pump(testDuration + const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      expect(find.text('Hey there!'), findsNothing);
    });

    testWidgets('upward swipe dismisses the banner', (tester) async {
      await _showPopup(tester, friendName: 'Alice');

      await tester.fling(find.text('Alice'), const Offset(0, -150), 600);
      await tester.pumpAndSettle();

      expect(find.text('Alice'), findsNothing);

      await _drain(tester);
    });

    testWidgets('downward swipe does not dismiss the banner', (tester) async {
      await _showPopup(tester, friendName: 'Alice');

      await tester.fling(find.text('Alice'), const Offset(0, 150), 600);
      await tester.pump();

      expect(find.text('Alice'), findsOneWidget);

      await _drain(tester);
    });

    testWidgets('friend name is present in the semantics tree', (tester) async {
      final handle = tester.ensureSemantics();
      try {
        await _showPopup(tester, friendName: 'Alice');

        // The combined semantics label for the banner includes the friend name.
        final node = tester.getSemantics(find.text('Alice'));
        expect(node.label, contains('Alice'));

        await _drain(tester);
      } finally {
        handle.dispose();
      }
    });
  });
}
