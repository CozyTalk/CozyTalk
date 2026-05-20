import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/screens/dress_up_screen.dart';
import 'package:mobile/shared/avatar_overlay.dart';

class _FakeAvatarNotifier extends AvatarNotifier {
  final AvatarState _initial;
  int setMoodCount = 0;
  int setAccessoryCount = 0;
  AvatarOverlay? lastAccessory;

  _FakeAvatarNotifier({AvatarState initial = const AvatarState()})
    : _initial = initial;

  @override
  AvatarState build() => _initial;

  @override
  Future<void> setMood(AvatarOverlay? v) async => setMoodCount++;

  @override
  Future<void> setAccessory(AvatarOverlay? v) async {
    setAccessoryCount++;
    lastAccessory = v;
  }
}

Widget _build(_FakeAvatarNotifier fake) => ProviderScope(
  overrides: [avatarProvider.overrideWith(() => fake)],
  child: const MaterialApp(home: DressUpScreen()),
);

void main() {
  group('DressUpScreen', () {
    testWidgets('renders without error', (tester) async {
      await tester.pumpWidget(_build(_FakeAvatarNotifier()));
      await tester.pump();
      expect(find.byType(DressUpScreen), findsOneWidget);
    });

    testWidgets('shows Dress up title in header', (tester) async {
      await tester.pumpWidget(_build(_FakeAvatarNotifier()));
      await tester.pump();
      expect(find.text('Dress up'), findsOneWidget);
    });

    testWidgets('shows all 6 accessory items', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_build(_FakeAvatarNotifier()));
      await tester.pump();

      expect(find.text('Cap'), findsOneWidget);
      expect(find.text('Beanie'), findsOneWidget);
      expect(find.text('Witch Hat'), findsOneWidget);
      expect(find.text('Sunglasses'), findsOneWidget);
      expect(find.text('Cat Headband'), findsOneWidget);
      expect(find.text('Crown'), findsOneWidget);
    });

    testWidgets('tapping an accessory calls setAccessory on the notifier', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final fake = _FakeAvatarNotifier();
      await tester.pumpWidget(_build(fake));
      await tester.pump();

      await tester.tap(find.text('Cap'));
      await tester.pump();

      expect(fake.setAccessoryCount, 1);
      expect(fake.lastAccessory, equals(AvatarOverlays.accessory['Cap']));
    });

    testWidgets('Save button is present', (tester) async {
      await tester.pumpWidget(_build(_FakeAvatarNotifier()));
      await tester.pump();
      expect(find.text('Save'), findsOneWidget);
    });
  });
}
