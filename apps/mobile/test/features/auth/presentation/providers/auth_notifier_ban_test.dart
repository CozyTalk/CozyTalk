import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/auth/data/datasources/auth_datasource.dart'
    show BanException;
import 'package:mobile/features/auth/domain/entities/auth_user.dart';
import 'package:mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:mobile/shared/prefs_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/shared_fakes.dart';

// Extended fake that supports triggering a ban via stream controller.
class _BanableFakeRepo extends FakeAuthRepository {
  final _banController = StreamController<(int, String)?>.broadcast();
  BanException? checkBanError;

  @override
  Future<void> checkBanStatus(String uid) async {
    if (checkBanError != null) throw checkBanError!;
  }

  @override
  Stream<(int, String)?> watchBanStatus(String uid) => _banController.stream;

  void emitBan({int daysLeft = 30, String reinstateDate = 'Jun 15, 2026'}) {
    _banController.add((daysLeft, reinstateDate));
  }

  void emitUnban() => _banController.add(null);

  Future<void> dispose() => _banController.close();
}

void main() {
  group('AuthNotifier — ban behaviour', () {
    late _BanableFakeRepo repo;
    late ProviderContainer container;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      repo = _BanableFakeRepo()
        ..returnUser = const AuthUser(uid: 'uid-1', displayName: 'Tester');
      container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          authRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await repo.dispose();
      });
    });

    test(
      'sign-in with banned account sets isBanned with correct details',
      () async {
        repo.error = BanException(daysLeft: 14, reinstateDate: 'Jul 1, 2026');

        await container
            .read(authNotifierProvider.notifier)
            .signIn(email: 'x@x.com', password: 'pass');

        final state = container.read(authNotifierProvider);
        expect(state.isBanned, isTrue);
        expect(state.banDaysLeft, 14);
        expect(state.banReinstateDate, 'Jul 1, 2026');
        expect(state.status, AuthStatus.unauthenticated);
      },
    );

    test('isBanned resets to false at the start of a retry sign-in', () async {
      // First attempt — banned.
      repo.error = BanException(daysLeft: 7, reinstateDate: 'Jun 10, 2026');
      await container
          .read(authNotifierProvider.notifier)
          .signIn(email: 'x@x.com', password: 'pass');
      expect(container.read(authNotifierProvider).isBanned, isTrue);

      // Second attempt — also banned but with different details.
      repo.error = BanException(daysLeft: 5, reinstateDate: 'Jun 8, 2026');
      await container
          .read(authNotifierProvider.notifier)
          .signIn(email: 'x@x.com', password: 'pass');

      final state = container.read(authNotifierProvider);
      expect(state.isBanned, isTrue);
      expect(state.banDaysLeft, 5);
      expect(state.banReinstateDate, 'Jun 8, 2026');
    });

    test(
      'confirmBanAndSignOut transitions to unauthenticated + isBanned + not bannedWhileActive',
      () async {
        // Set up a logged-in state via watchAuthState.
        repo.watchStateFactory = () =>
            Stream.fromFuture(Future.value(const AuthUser(uid: 'uid-1')));
        final sub = container.listen(authNotifierProvider, (_, _) {});
        addTearDown(sub.close);
        await Future<void>.delayed(Duration.zero);

        // Trigger ban while active.
        repo.emitBan(daysLeft: 30, reinstateDate: 'Jul 15, 2026');
        await Future<void>.delayed(Duration.zero);
        expect(container.read(authNotifierProvider).bannedWhileActive, isTrue);

        // User confirms — signs out.
        await container
            .read(authNotifierProvider.notifier)
            .confirmBanAndSignOut();

        final state = container.read(authNotifierProvider);
        expect(state.status, AuthStatus.unauthenticated);
        expect(state.isBanned, isTrue);
        expect(state.bannedWhileActive, isFalse);
        expect(state.user, isNull);
        expect(repo.signOutCount, 1);
      },
    );

    test(
      '_subscribeToBan sets bannedWhileActive when ban stream emits',
      () async {
        repo.watchStateFactory = () =>
            Stream.fromFuture(Future.value(const AuthUser(uid: 'uid-1')));
        final sub = container.listen(authNotifierProvider, (_, _) {});
        addTearDown(sub.close);
        await Future<void>.delayed(Duration.zero);

        expect(container.read(authNotifierProvider).bannedWhileActive, isFalse);

        repo.emitBan(daysLeft: 30, reinstateDate: 'Jun 15, 2026');
        await Future<void>.delayed(Duration.zero);

        final state = container.read(authNotifierProvider);
        expect(state.bannedWhileActive, isTrue);
        expect(state.banDaysLeft, 30);
        expect(state.banReinstateDate, 'Jun 15, 2026');
      },
    );

    test(
      'checkBanStatus throwing BanException on startup sets isBanned on LoginScreen path',
      () async {
        // Simulate app startup with cached session that is now banned.
        repo.watchStateFactory = () =>
            Stream.fromFuture(Future.value(const AuthUser(uid: 'uid-1')));
        repo.checkBanError = BanException(
          daysLeft: 7,
          reinstateDate: 'Jun 10, 2026',
        );

        final sub = container.listen(authNotifierProvider, (_, _) {});
        addTearDown(sub.close);
        // Allow watchAuthState and _checkTokenAndBan Future to settle.
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        final state = container.read(authNotifierProvider);
        expect(state.status, AuthStatus.unauthenticated);
        expect(state.isBanned, isTrue);
        expect(state.banDaysLeft, 7);
        expect(state.banReinstateDate, 'Jun 10, 2026');
      },
    );
  });
}
