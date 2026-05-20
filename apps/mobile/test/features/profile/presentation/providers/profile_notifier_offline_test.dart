import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/profile/domain/entities/profile_user.dart';
import 'package:mobile/features/profile/presentation/providers/profile_provider.dart';
import 'package:mobile/shared/connectivity_provider.dart';
import 'package:mobile/shared/network_info.dart';
import 'package:mobile/shared/prefs_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/shared_fakes.dart';

class _FakeNetworkInfo implements NetworkInfo {
  final bool _isOnline;
  _FakeNetworkInfo({required bool isOnline}) : _isOnline = isOnline;

  @override
  Stream<bool> get onConnectivityChanged => Stream.value(_isOnline);

  @override
  Future<bool> get isConnected async => _isOnline;
}

ProviderContainer _buildContainer({
  required FakeProfileRepository repo,
  required bool isOnline,
  required SharedPreferences prefs,
}) {
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      networkInfoProvider.overrideWithValue(
        _FakeNetworkInfo(isOnline: isOnline),
      ),
      profileRepositoryProvider.overrideWithValue(repo),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  late FakeProfileRepository repo;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    repo = FakeProfileRepository();
  });

  group('ProfileNotifier — load() fallback', () {
    test('online success: profile set, no error', () async {
      const user = ProfileUser(uid: 'u1', displayName: 'Alice');
      repo.returnProfile = user;

      final container = _buildContainer(
        repo: repo,
        isOnline: true,
        prefs: prefs,
      );
      await container.read(profileNotifierProvider.notifier).load('u1');

      final state = container.read(profileNotifierProvider);
      expect(state.profile?.displayName, 'Alice');
      expect(state.error, isNull);
      expect(state.isLoading, isFalse);
    });

    test('repository throws AND cache miss: error set in state', () async {
      repo.error = Exception('network error');
      repo.returnCachedProfile = null;

      final container = _buildContainer(
        repo: repo,
        isOnline: true,
        prefs: prefs,
      );
      await container.read(profileNotifierProvider.notifier).load('u1');

      final state = container.read(profileNotifierProvider);
      expect(state.error, isNotNull);
      expect(state.profile, isNull);
    });
  });

  group('ProfileNotifier — write guards offline', () {
    test(
      'updateDisplayName offline: sets error, does NOT call repository',
      () async {
        final container = _buildContainer(
          repo: repo,
          isOnline: false,
          prefs: prefs,
        );
        await container
            .read(profileNotifierProvider.notifier)
            .updateDisplayName('u1', 'Alice');

        final state = container.read(profileNotifierProvider);
        expect(state.error, contains('offline'));
        expect(repo.updateDisplayNameCount, 0);
      },
    );

    test(
      'updateInterest offline: sets error, does NOT call repository',
      () async {
        final container = _buildContainer(
          repo: repo,
          isOnline: false,
          prefs: prefs,
        );
        await container
            .read(profileNotifierProvider.notifier)
            .updateInterest('u1', 'music');

        final state = container.read(profileNotifierProvider);
        expect(state.error, contains('offline'));
        expect(repo.updateInterestCount, 0);
      },
    );

    test(
      'updateThoughts offline: sets error, does NOT call repository',
      () async {
        final container = _buildContainer(
          repo: repo,
          isOnline: false,
          prefs: prefs,
        );
        await container
            .read(profileNotifierProvider.notifier)
            .updateThoughts('u1', 'happy');

        final state = container.read(profileNotifierProvider);
        expect(state.error, contains('offline'));
        expect(repo.updateThoughtsCount, 0);
      },
    );

    test('updateDisplayName online: calls repository', () async {
      repo.returnProfile = const ProfileUser(uid: 'u1', displayName: 'Alice');
      final container = _buildContainer(
        repo: repo,
        isOnline: true,
        prefs: prefs,
      );
      await container
          .read(profileNotifierProvider.notifier)
          .updateDisplayName('u1', 'Alice');

      expect(repo.updateDisplayNameCount, 1);
    });
  });
}
