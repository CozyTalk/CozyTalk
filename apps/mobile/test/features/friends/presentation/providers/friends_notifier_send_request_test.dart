import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/auth/domain/entities/auth_user.dart';
import 'package:mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:mobile/features/friends/domain/entities/app_user.dart';
import 'package:mobile/features/friends/presentation/providers/friends_provider.dart';
import 'package:mobile/features/profile/domain/entities/profile_user.dart';
import 'package:mobile/features/profile/presentation/providers/profile_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/shared_fakes.dart';

// ── Fakes ─────────────────────────────────────────────────────────────────────

class _FakeProfileNotifier extends ProfileNotifier {
  final ProfileState _initial;
  _FakeProfileNotifier(this._initial);

  @override
  ProfileState build() => _initial;
}

class _FakeAuthNotifier extends AuthNotifier {
  final AuthState _initial;
  _FakeAuthNotifier(this._initial);

  @override
  AuthState build() => _initial;

  @override
  Future<void> signIn({
    required String email,
    required String password,
  }) async {}
  @override
  Future<void> signUp({
    required String email,
    required String password,
  }) async {}
  @override
  Future<void> signOut() async {}
  @override
  Future<void> signInAnonymously() async {}
  @override
  Future<void> signInWithGoogle() async {}
}

// ── Auth state helpers ────────────────────────────────────────────────────────

AuthState _anonAuth() => const AuthState(
  status: AuthStatus.authenticated,
  user: AuthUser(uid: 'anon-uid', email: null, displayName: 'CuriousFox'),
);

AuthState _emailAuth() => const AuthState(
  status: AuthStatus.authenticated,
  user: AuthUser(
    uid: 'real-uid',
    email: 'alice@example.com',
    displayName: 'Alice',
  ),
);

const _target = AppUser(uid: 'target-uid', displayName: 'Bob');

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  group('FriendsNotifier.sendFriendRequest — anonymous guard', () {
    late FakeFriendsRepository repo;
    late ProviderContainer container;

    void setUp(AuthState auth) {
      SharedPreferences.setMockInitialValues({});
      repo = FakeFriendsRepository();
      container = ProviderContainer(
        overrides: [
          authNotifierProvider.overrideWith(() => _FakeAuthNotifier(auth)),
          friendsRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);
    }

    test('anonymous user: error is set, repository is never called', () async {
      setUp(_anonAuth());
      await container
          .read(friendsNotifierProvider.notifier)
          .sendFriendRequest(_target);

      expect(container.read(friendsNotifierProvider).error, isNotNull);
      expect(repo.sendFriendRequestCount, 0);
    });

    test('anonymous user: error message contains "sign in"', () async {
      setUp(_anonAuth());
      await container
          .read(friendsNotifierProvider.notifier)
          .sendFriendRequest(_target);

      final error = container.read(friendsNotifierProvider).error!;
      expect(error.toLowerCase(), contains('sign in'));
    });

    test(
      'anonymous user: isLoading stays false (no half-started mutation)',
      () async {
        setUp(_anonAuth());
        await container
            .read(friendsNotifierProvider.notifier)
            .sendFriendRequest(_target);

        expect(container.read(friendsNotifierProvider).isLoading, isFalse);
      },
    );

    test('email user: request is forwarded to repository', () async {
      setUp(_emailAuth());
      await container
          .read(friendsNotifierProvider.notifier)
          .sendFriendRequest(_target);

      expect(repo.sendFriendRequestCount, 1);
      expect(container.read(friendsNotifierProvider).error, isNull);
    });

    test('email user: correct toUid and displayName forwarded', () async {
      setUp(_emailAuth());
      repo.usersById = [const AppUser(uid: 'real-uid', displayName: 'Alice')];
      await container
          .read(friendsNotifierProvider.notifier)
          .sendFriendRequest(_target);

      expect(repo.lastToUid, 'target-uid');
      expect(repo.lastToDisplayName, 'Bob');
      expect(repo.lastFromDisplayName, 'Alice');
    });
  });

  group('FriendsNotifier.sendFriendRequest — fromDisplayName priority', () {
    late FakeFriendsRepository repo;
    late ProviderContainer container;

    void setUp(AuthState auth, ProfileState profile) {
      SharedPreferences.setMockInitialValues({});
      repo = FakeFriendsRepository();
      container = ProviderContainer(
        overrides: [
          authNotifierProvider.overrideWith(() => _FakeAuthNotifier(auth)),
          profileNotifierProvider.overrideWith(
            () => _FakeProfileNotifier(profile),
          ),
          friendsRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);
    }

    test('uses profile displayName when profile is loaded', () async {
      setUp(
        _emailAuth(),
        ProfileState(
          profile: const ProfileUser(
            uid: 'real-uid',
            displayName: 'AliceFromProfile',
          ),
        ),
      );
      await container
          .read(friendsNotifierProvider.notifier)
          .sendFriendRequest(_target);

      expect(repo.lastFromDisplayName, 'AliceFromProfile');
    });

    test('falls back to authUser displayName when profile is null', () async {
      setUp(_emailAuth(), const ProfileState());
      await container
          .read(friendsNotifierProvider.notifier)
          .sendFriendRequest(_target);

      expect(repo.lastFromDisplayName, 'Alice');
    });

    test(
      'falls back to authUser displayName when profile displayName is empty',
      () async {
        setUp(
          _emailAuth(),
          ProfileState(
            profile: const ProfileUser(uid: 'real-uid', displayName: ''),
          ),
        );
        await container
            .read(friendsNotifierProvider.notifier)
            .sendFriendRequest(_target);

        expect(repo.lastFromDisplayName, 'Alice');
      },
    );

    test(
      'falls back to authUser displayName when profile displayName is whitespace',
      () async {
        setUp(
          _emailAuth(),
          ProfileState(
            profile: const ProfileUser(uid: 'real-uid', displayName: '   '),
          ),
        );
        await container
            .read(friendsNotifierProvider.notifier)
            .sendFriendRequest(_target);

        expect(repo.lastFromDisplayName, 'Alice');
      },
    );
  });
}
