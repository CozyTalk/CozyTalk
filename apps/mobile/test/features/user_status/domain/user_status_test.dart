import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/user_status/domain/entities/user_status.dart';
import 'package:mobile/features/user_status/domain/usecases/clear_status.dart';
import 'package:mobile/features/user_status/domain/usecases/set_in_room.dart';
import 'package:mobile/features/user_status/domain/usecases/set_online.dart';
import 'package:mobile/features/user_status/domain/usecases/watch_user_status.dart';
import 'package:mobile/features/user_status/domain/repositories/user_status_repository.dart';

// ── Fakes ─────────────────────────────────────────────────────────────────────

class _FakeUserStatusRepository implements UserStatusRepository {
  UserStatus? _returnValue;
  Exception? _error;
  String? lastWatchedUid;
  int setOnlineCount = 0;
  String? lastRoomId;
  String? lastMode;
  int clearCount = 0;

  void givenStatus(UserStatus value) => _returnValue = value;
  void givenError(Exception error) => _error = error;

  @override
  Stream<UserStatus> watchStatus(String uid) {
    lastWatchedUid = uid;
    if (_error != null) return Stream.error(_error!);
    return Stream.value(_returnValue!);
  }

  @override
  Future<void> setOnline() async {
    if (_error != null) throw _error!;
    setOnlineCount++;
  }

  @override
  Future<void> setInRoom({required String roomId, required String mode}) async {
    if (_error != null) throw _error!;
    lastRoomId = roomId;
    lastMode = mode;
  }

  @override
  Future<void> clearStatus() async {
    if (_error != null) throw _error!;
    clearCount++;
  }
}

// ── Entity tests ──────────────────────────────────────────────────────────────

void main() {
  group('UserStatus entity', () {
    test('constructs with required uid and status', () {
      const status = UserStatus(uid: 'u1', status: UserOnlineStatus.online);
      expect(status.uid, 'u1');
      expect(status.status, UserOnlineStatus.online);
      expect(status.roomId, isNull);
      expect(status.roomMode, isNull);
    });

    test('constructs with room fields when in_room', () {
      const status = UserStatus(
        uid: 'u1',
        status: UserOnlineStatus.inRoom,
        roomId: 'abc12',
        roomMode: '1v1',
      );
      expect(status.roomId, 'abc12');
      expect(status.roomMode, '1v1');
    });

    test('offline status has null room fields', () {
      const status = UserStatus(uid: 'u1', status: UserOnlineStatus.offline);
      expect(status.status, UserOnlineStatus.offline);
      expect(status.roomId, isNull);
      expect(status.roomMode, isNull);
    });
  });

  group('UserOnlineStatus enum', () {
    test('contains all expected values', () {
      expect(
        UserOnlineStatus.values,
        containsAll([
          UserOnlineStatus.online,
          UserOnlineStatus.inRoom,
          UserOnlineStatus.offline,
        ]),
      );
      expect(UserOnlineStatus.values, hasLength(3));
    });
  });

  group('WatchUserStatus usecase', () {
    late _FakeUserStatusRepository repo;
    late WatchUserStatus usecase;

    setUp(() {
      repo = _FakeUserStatusRepository();
      usecase = WatchUserStatus(repo);
    });

    test('forwards uid to repository and returns stream', () async {
      repo.givenStatus(
        const UserStatus(uid: 'u1', status: UserOnlineStatus.online),
      );
      final result = await usecase('u1').first;
      expect(repo.lastWatchedUid, 'u1');
      expect(result.status, UserOnlineStatus.online);
    });

    test('propagates repository errors', () {
      repo.givenError(Exception('rtdb error'));
      expect(usecase('u1'), emitsError(isA<Exception>()));
    });
  });

  group('SetOnline usecase', () {
    late _FakeUserStatusRepository repo;
    late SetOnline usecase;

    setUp(() {
      repo = _FakeUserStatusRepository();
      usecase = SetOnline(repo);
    });

    test('delegates to repository', () async {
      await usecase();
      expect(repo.setOnlineCount, 1);
    });

    test('propagates exception', () async {
      repo.givenError(Exception('fail'));
      await expectLater(usecase(), throwsA(isA<Exception>()));
    });
  });

  group('SetInRoom usecase', () {
    late _FakeUserStatusRepository repo;
    late SetInRoom usecase;

    setUp(() {
      repo = _FakeUserStatusRepository();
      usecase = SetInRoom(repo);
    });

    test('forwards roomId and mode to repository', () async {
      await usecase(roomId: 'abc12', mode: '1v1');
      expect(repo.lastRoomId, 'abc12');
      expect(repo.lastMode, '1v1');
    });

    test('propagates exception', () async {
      repo.givenError(Exception('fail'));
      await expectLater(
        usecase(roomId: 'abc12', mode: 'group'),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('ClearStatus usecase', () {
    late _FakeUserStatusRepository repo;
    late ClearStatus usecase;

    setUp(() {
      repo = _FakeUserStatusRepository();
      usecase = ClearStatus(repo);
    });

    test('delegates to repository', () async {
      await usecase();
      expect(repo.clearCount, 1);
    });

    test('propagates exception', () async {
      repo.givenError(Exception('fail'));
      await expectLater(usecase(), throwsA(isA<Exception>()));
    });
  });
}
