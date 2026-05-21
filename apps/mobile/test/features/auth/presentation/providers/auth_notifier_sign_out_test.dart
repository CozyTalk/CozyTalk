import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/auth/domain/entities/auth_user.dart';
import 'package:mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:mobile/shared/cache_keys.dart';
import 'package:mobile/shared/prefs_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/shared_fakes.dart';

void main() {
  group('AuthNotifier.signOut — cache clearing', () {
    test('clears profile and avatar cache keys for signed-in user', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      const uid = 'test-uid-1';

      // Seed both cache entries before sign-out.
      await prefs.setString(CacheKeys.profile(uid), '{"uid":"$uid"}');
      await prefs.setString(CacheKeys.avatar(uid), '{"hatKey":"Crown"}');

      // FakeAuthRepository.watchAuthState emits the user asynchronously so
      // build() can return before the stream fires (required by Riverpod).
      final fakeRepo = FakeAuthRepository()
        ..watchStateFactory = () =>
            Stream.fromFuture(Future.value(const AuthUser(uid: uid)));

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          authRepositoryProvider.overrideWithValue(fakeRepo),
        ],
      );
      addTearDown(container.dispose);

      // Subscribe to trigger build() and let the auth stream settle.
      final sub = container.listen(authNotifierProvider, (_, _) {});
      addTearDown(sub.close);
      await Future<void>.delayed(Duration.zero);

      expect(container.read(authNotifierProvider).user?.uid, uid);

      await container.read(authNotifierProvider.notifier).signOut();

      expect(prefs.getString(CacheKeys.profile(uid)), isNull);
      expect(prefs.getString(CacheKeys.avatar(uid)), isNull);
    });

    test(
      'does not throw when signing out with no authenticated user',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();

        final fakeRepo = FakeAuthRepository();

        final container = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            authRepositoryProvider.overrideWithValue(fakeRepo),
          ],
        );
        addTearDown(container.dispose);

        // No user — state.user is null; signOut should be a no-op on cache.
        await expectLater(
          container.read(authNotifierProvider.notifier).signOut(),
          completes,
        );
      },
    );
  });
}
