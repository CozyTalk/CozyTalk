import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/screens/mood_screen.dart';
import 'package:mobile/shared/avatar_overlay.dart';

class _FakeAvatarNotifier extends AvatarNotifier {
  final AvatarState _initial;
  int setMoodCount = 0;
  int setAccessoryCount = 0;
  AvatarOverlay? lastMood;

  _FakeAvatarNotifier({AvatarState initial = const AvatarState()})
    : _initial = initial;

  @override
  AvatarState build() => _initial;

  @override
  Future<void> setMood(AvatarOverlay? v) async {
    setMoodCount++;
    lastMood = v;
  }

  @override
  Future<void> setAccessory(AvatarOverlay? v) async => setAccessoryCount++;
}

Widget _build(_FakeAvatarNotifier fake) => ProviderScope(
  overrides: [avatarProvider.overrideWith(() => fake)],
  child: const MaterialApp(home: MoodScreen()),
);

void main() {
  group('MoodScreen', () {
    testWidgets('renders without error', (tester) async {
      await tester.pumpWidget(_build(_FakeAvatarNotifier()));
      await tester.pump();
      expect(find.byType(MoodScreen), findsOneWidget);
    });

    testWidgets('shows Mood title in header', (tester) async {
      await tester.pumpWidget(_build(_FakeAvatarNotifier()));
      await tester.pump();
      expect(find.text('Mood'), findsOneWidget);
    });

    testWidgets('shows all 6 mood options', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_build(_FakeAvatarNotifier()));
      await tester.pump();

      expect(find.text('Happy'), findsOneWidget);
      expect(find.text('Thrilled'), findsOneWidget);
      expect(find.text('Sad'), findsOneWidget);
      expect(find.text('Lonely'), findsOneWidget);
      expect(find.text('Silly'), findsOneWidget);
      expect(find.text('Grumpy'), findsOneWidget);
    });

    testWidgets('tapping a mood calls setMood on the notifier', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final fake = _FakeAvatarNotifier();
      await tester.pumpWidget(_build(fake));
      await tester.pump();

      await tester.tap(find.text('Thrilled'));
      await tester.pump();

      expect(fake.setMoodCount, 1);
      expect(fake.lastMood, equals(AvatarOverlays.mood['Thrilled']));
    });

    testWidgets('Save button is present', (tester) async {
      await tester.pumpWidget(_build(_FakeAvatarNotifier()));
      await tester.pump();
      expect(find.text('Save'), findsOneWidget);
    });
  });
}
