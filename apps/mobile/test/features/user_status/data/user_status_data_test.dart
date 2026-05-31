import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/user_status/data/datasources/user_status_datasource.dart';
import 'package:mobile/features/user_status/data/models/user_status_model.dart';
import 'package:mobile/features/user_status/data/repositories/user_status_repository_impl.dart';
import 'package:mobile/features/user_status/domain/entities/user_status.dart';

// ── Model tests ───────────────────────────────────────────────────────────────

void main() {
  group('UserStatusModel', () {
    test('fromJson with online status', () {
      final model = UserStatusModel.fromJson({'status': 'online'});
      expect(model.status, 'online');
      expect(model.roomId, isNull);
      expect(model.roomMode, isNull);
    });

    test('fromJson with in_room status and room fields', () {
      final model = UserStatusModel.fromJson({
        'status': 'in_room',
        'roomId': 'abc12',
        'roomMode': '1v1',
      });
      expect(model.status, 'in_room');
      expect(model.roomId, 'abc12');
      expect(model.roomMode, '1v1');
    });

    test('fromJson ignores unknown keys', () {
      final model = UserStatusModel.fromJson({
        'status': 'online',
        'unknown': 'ignored',
      });
      expect(model.status, 'online');
    });

    test('toEntity maps online correctly', () {
      const model = UserStatusModel(status: 'online');
      final entity = model.toEntity('u1');
      expect(entity.uid, 'u1');
      expect(entity.status, UserOnlineStatus.online);
      expect(entity.roomId, isNull);
    });

    test('toEntity maps in_room correctly', () {
      const model = UserStatusModel(
        status: 'in_room',
        roomId: 'abc12',
        roomMode: 'group',
      );
      final entity = model.toEntity('u2');
      expect(entity.status, UserOnlineStatus.inRoom);
      expect(entity.roomId, 'abc12');
      expect(entity.roomMode, 'group');
    });

    test('toEntity treats unknown status string as online', () {
      const model = UserStatusModel(status: 'unknown_value');
      expect(model.toEntity('u1').status, UserOnlineStatus.online);
    });
  });

  // ── Repository tests ─────────────────────────────────────────────────────────

  group('UserStatusRepositoryImpl', () {
    late _FakeDatasource ds;
    late UserStatusRepositoryImpl repo;

    setUp(() {
      ds = _FakeDatasource();
      repo = UserStatusRepositoryImpl(ds);
    });

    test('watchStatus emits offline when datasource emits null', () async {
      ds.watchReturn = Stream.value(null);
      final result = await repo.watchStatus('u1').first;
      expect(result.uid, 'u1');
      expect(result.status, UserOnlineStatus.offline);
    });

    test('watchStatus converts model to entity', () async {
      ds.watchReturn = Stream.value(
        const UserStatusModel(
          status: 'in_room',
          roomId: 'r1234',
          roomMode: '1v1',
        ),
      );
      final result = await repo.watchStatus('u1').first;
      expect(result.status, UserOnlineStatus.inRoom);
      expect(result.roomId, 'r1234');
    });

    test('setOnline delegates to datasource', () async {
      await repo.setOnline();
      expect(ds.setOnlineCount, 1);
    });

    test('setInRoom delegates to datasource', () async {
      await repo.setInRoom(roomId: 'abc12', mode: 'group');
      expect(ds.lastRoomId, 'abc12');
      expect(ds.lastMode, 'group');
    });

    test('clearStatus delegates to datasource', () async {
      await repo.clearStatus();
      expect(ds.clearCount, 1);
    });

    test('watchOnlineCount delegates to datasource', () async {
      ds.onlineCountReturn = Stream.value(7);
      final result = await repo.watchOnlineCount().first;
      expect(result, 7);
    });
  });
}

class _FakeDatasource implements UserStatusDatasource {
  Stream<UserStatusModel?> watchReturn = Stream.value(null);
  Stream<int> onlineCountReturn = Stream.value(0);
  int setOnlineCount = 0;
  String? lastRoomId;
  String? lastMode;
  int clearCount = 0;

  @override
  Stream<UserStatusModel?> watchStatus(String uid) => watchReturn;

  @override
  Stream<int> watchOnlineCount() => onlineCountReturn;

  @override
  Future<void> setOnline() async => setOnlineCount++;

  @override
  Future<void> setInRoom({required String roomId, required String mode}) async {
    lastRoomId = roomId;
    lastMode = mode;
  }

  @override
  Future<void> clearStatus() async => clearCount++;
}
