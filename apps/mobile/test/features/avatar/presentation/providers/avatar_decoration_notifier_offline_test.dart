import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/avatar/domain/entities/avatar_decoration.dart';
import 'package:mobile/features/avatar/presentation/providers/avatar_decoration_provider.dart';
import 'package:mobile/shared/connectivity_provider.dart';
import 'package:mobile/shared/prefs_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/shared_fakes.dart';
import '../../../../shared/fake_network_info.dart';

ProviderContainer _buildContainer({
  required FakeAvatarRepository repo,
  required bool isOnline,
  required SharedPreferences prefs,
}) {
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      networkInfoProvider.overrideWithValue(
        FakeNetworkInfo(isOnline: isOnline),
      ),
      avatarRepositoryProvider.overrideWithValue(repo),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  late FakeAvatarRepository repo;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    repo = FakeAvatarRepository();
  });

  group('AvatarDecorationNotifier — load() fallback', () {
    test('success: decoration set, status idle', () async {
      const decoration = AvatarDecoration(hatKey: 'Crown', moodKey: 'Happy');
      repo.returnDecoration = decoration;

      final container = _buildContainer(
        repo: repo,
        isOnline: true,
        prefs: prefs,
      );
      await container
          .read(avatarDecorationNotifierProvider.notifier)
          .load('u1');

      final state = container.read(avatarDecorationNotifierProvider);
      expect(state.decoration?.hatKey, 'Crown');
      expect(state.status, AvatarDecorationStatus.idle);
    });

    test(
      'double miss (null from repo): status idle with null decoration',
      () async {
        repo.returnDecoration = null;

        final container = _buildContainer(
          repo: repo,
          isOnline: true,
          prefs: prefs,
        );
        await container
            .read(avatarDecorationNotifierProvider.notifier)
            .load('u1');

        final state = container.read(avatarDecorationNotifierProvider);
        expect(state.decoration, isNull);
        expect(state.status, AvatarDecorationStatus.idle);
      },
    );
  });

  group('AvatarDecorationNotifier — write guards offline', () {
    test('updateHat offline: sets error, does NOT call repository', () async {
      final container = _buildContainer(
        repo: repo,
        isOnline: false,
        prefs: prefs,
      );
      await container
          .read(avatarDecorationNotifierProvider.notifier)
          .updateHat('u1', 'Crown');

      final state = container.read(avatarDecorationNotifierProvider);
      expect(state.status, AvatarDecorationStatus.error);
      expect(state.error, contains('offline'));
      expect(repo.updateHatCount, 0);
    });

    test('updateMood offline: sets error, does NOT call repository', () async {
      final container = _buildContainer(
        repo: repo,
        isOnline: false,
        prefs: prefs,
      );
      await container
          .read(avatarDecorationNotifierProvider.notifier)
          .updateMood('u1', 'Happy');

      final state = container.read(avatarDecorationNotifierProvider);
      expect(state.status, AvatarDecorationStatus.error);
      expect(repo.updateMoodCount, 0);
    });

    test(
      'updateDecoration offline: sets error, does NOT call repository',
      () async {
        final container = _buildContainer(
          repo: repo,
          isOnline: false,
          prefs: prefs,
        );
        await container
            .read(avatarDecorationNotifierProvider.notifier)
            .updateDecoration('u1', 'Crown', 'Happy');

        final state = container.read(avatarDecorationNotifierProvider);
        expect(state.status, AvatarDecorationStatus.error);
        expect(repo.updateDecorationCount, 0);
      },
    );

    test('updateHat online: calls repository', () async {
      repo.returnDecoration = const AvatarDecoration(hatKey: 'Crown');
      final container = _buildContainer(
        repo: repo,
        isOnline: true,
        prefs: prefs,
      );
      await container
          .read(avatarDecorationNotifierProvider.notifier)
          .updateHat('u1', 'Crown');

      expect(repo.updateHatCount, 1);
    });
  });
}
