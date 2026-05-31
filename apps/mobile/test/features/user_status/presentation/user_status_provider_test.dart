import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/auth/domain/entities/auth_user.dart';
import 'package:mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:mobile/features/matchmaking/presentation/providers/matchmaking_provider.dart';
import 'package:mobile/features/user_status/domain/entities/user_status.dart';
import 'package:mobile/features/user_status/domain/repositories/user_status_repository.dart';
import 'package:mobile/features/user_status/presentation/providers/user_status_provider.dart';

// ── Fakes ─────────────────────────────────────────────────────────────────────

class _FakeUserStatusRepository implements UserStatusRepository {
  int setOnlineCount = 0;
  int clearCount = 0;
  String? lastRoomId;
  String? lastMode;

  @override
  Stream<UserStatus> watchStatus(String uid) => const Stream.empty();

  @override
  Future<void> setOnline() async => setOnlineCount++;

  @override
  Future<void> setInRoom({
    required String roomId,
    required String mode,
    required int maxUsers,
    required int memberCount,
    required bool isLocked,
    String? backgroundTheme,
  }) async {
    lastRoomId = roomId;
    lastMode = mode;
  }

  @override
  Future<void> clearStatus() async => clearCount++;
}

class _FakeAuthNotifier extends AuthNotifier {
  final AuthState _initial;
  _FakeAuthNotifier(this._initial);

  @override
  AuthState build() => _initial;
}

class _FakeMatchmakingNotifier extends MatchmakingNotifier {
  final MatchmakingState _initial;
  _FakeMatchmakingNotifier(this._initial);

  @override
  MatchmakingState build() => _initial;
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  group('OwnStatusNotifier', () {
    test('can be read when auth is authenticated without throwing', () async {
      final container = ProviderContainer(
        overrides: [
          authNotifierProvider.overrideWith(
            () => _FakeAuthNotifier(
              AuthState(
                status: AuthStatus.authenticated,
                user: const AuthUser(uid: 'u1'),
              ),
            ),
          ),
          matchmakingNotifierProvider.overrideWith(
            () => _FakeMatchmakingNotifier(const MatchmakingState()),
          ),
        ],
      );
      addTearDown(container.dispose);

      container.read(ownStatusNotifierProvider);
      await Future<void>.delayed(Duration.zero);

      expect(() => container.read(ownStatusNotifierProvider), returnsNormally);
    });

    test('can be disposed without errors', () {
      final container = ProviderContainer(
        overrides: [
          authNotifierProvider.overrideWith(
            () => _FakeAuthNotifier(const AuthState()),
          ),
          matchmakingNotifierProvider.overrideWith(
            () => _FakeMatchmakingNotifier(const MatchmakingState()),
          ),
        ],
      );
      container.read(ownStatusNotifierProvider);
      expect(() => container.dispose(), returnsNormally);
    });
  });

  group('UserStatusRepository direct tests', () {
    late _FakeUserStatusRepository repo;

    setUp(() => repo = _FakeUserStatusRepository());

    test('setOnline increments counter', () async {
      await repo.setOnline();
      await repo.setOnline();
      expect(repo.setOnlineCount, 2);
    });

    test('setInRoom records roomId and mode', () async {
      await repo.setInRoom(
        roomId: 'xyz99',
        mode: 'group',
        maxUsers: 5,
        memberCount: 1,
        isLocked: false,
      );
      expect(repo.lastRoomId, 'xyz99');
      expect(repo.lastMode, 'group');
    });

    test('clearStatus increments counter', () async {
      await repo.clearStatus();
      expect(repo.clearCount, 1);
    });
  });
}
