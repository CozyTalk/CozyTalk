import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/avatar/presentation/providers/avatar_decoration_provider.dart';
import 'package:mobile/shared/friend_request_popup.dart';

// Stub out the avatar provider so the banner renders without Firebase.
final _overrides = [
  avatarDecorationByUidProvider.overrideWith((ref, uid) async => null),
];

Widget _app({required Widget home}) => ProviderScope(
  overrides: _overrides,
  child: MaterialApp(home: home),
);

/// Shows the popup and pumps through the slide-in animation.
Future<void> _showPopup(
  WidgetTester tester, {
  String requesterName = 'Alice',
  String fromUid = 'uid-alice',
  VoidCallback? onAccept,
  VoidCallback? onDecline,
}) async {
  await tester.pumpWidget(
    _app(
      home: Builder(
        builder: (ctx) => ElevatedButton(
          onPressed: () => showFriendRequestPopup(
            ctx,
            requesterName: requesterName,
            fromUid: fromUid,
            onAccept: onAccept,
            onDecline: onDecline,
          ),
          child: const Text('Show'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Show'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350)); // slide-in animation
}

/// Drains the 5-second auto-dismiss timer and completes the slide-out so the
/// test ends with no pending timers or frames.
Future<void> _drain(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 6));
  await tester.pumpAndSettle();
}

void main() {
  group('FriendRequestPopup', () {
    testWidgets('shows Accept and Decline buttons', (tester) async {
      await _showPopup(tester);

      expect(find.text('Accept'), findsOneWidget);
      expect(find.text('Decline'), findsOneWidget);

      await _drain(tester);
    });

    testWidgets('Accept button has Semantics button role', (tester) async {
      final handle = tester.ensureSemantics();
      try {
        await _showPopup(tester);

        final node = tester.getSemantics(find.text('Accept'));
        expect(node.flagsCollection.isButton, isTrue);
        expect(node.label, 'Accept');

        await _drain(tester);
      } finally {
        handle.dispose();
      }
    });

    testWidgets('Decline button has Semantics button role', (tester) async {
      final handle = tester.ensureSemantics();
      try {
        await _showPopup(tester);

        final node = tester.getSemantics(find.text('Decline'));
        expect(node.flagsCollection.isButton, isTrue);
        expect(node.label, 'Decline');

        await _drain(tester);
      } finally {
        handle.dispose();
      }
    });

    testWidgets('tapping Accept fires onAccept and dismisses banner', (
      tester,
    ) async {
      bool accepted = false;
      await _showPopup(tester, onAccept: () => accepted = true);

      await tester.tap(find.text('Accept'));
      await tester.pumpAndSettle(); // dismiss animation
      await _drain(tester); // drain remaining 5s timer (no-op after dismiss)

      expect(accepted, isTrue);
      expect(find.text('Accept'), findsNothing);
    });

    testWidgets('tapping Decline fires onDecline and dismisses banner', (
      tester,
    ) async {
      bool declined = false;
      await _showPopup(tester, onDecline: () => declined = true);

      await tester.tap(find.text('Decline'));
      await tester.pumpAndSettle();
      await _drain(tester);

      expect(declined, isTrue);
      expect(find.text('Decline'), findsNothing);
    });

    testWidgets('banner renders requester name', (tester) async {
      await _showPopup(tester, requesterName: 'Bob', fromUid: 'uid-bob');

      expect(find.text('Bob'), findsOneWidget);
      expect(find.text('wants to add you as a friend'), findsOneWidget);

      await _drain(tester);
    });
  });
}
