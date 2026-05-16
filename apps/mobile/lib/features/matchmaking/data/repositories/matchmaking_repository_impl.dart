import '../../domain/entities/room.dart';
import '../../domain/repositories/matchmaking_repository.dart';
import '../datasources/matchmaking_datasource.dart';
import '../models/room_model.dart';

class MatchmakingRepositoryImpl implements MatchmakingRepository {
  final MatchmakingDatasource _datasource;

  MatchmakingRepositoryImpl(this._datasource);

  @override
  Future<({String roomId, bool isNewRoom})> joinGroupRoom() =>
      _datasource.joinGroupRoom();

  @override
  Future<String> createCustomRoom() => _datasource.createCustomRoom();

  @override
  Future<({String roomId, RoomMode mode, RoomType roomType})> joinRoomById(
    String roomId,
  ) => _datasource.joinRoomById(roomId);

  @override
  Future<void> leaveRoom(String roomId) => _datasource.leaveRoom(roomId);

  @override
  Future<void> join1v1Pool() => _datasource.join1v1Pool();

  @override
  Future<bool> cancel1v1Pool() => _datasource.cancel1v1Pool();

  @override
  Future<void> setRoomLock({required String roomId, required bool isLocked}) =>
      _datasource.setRoomLock(roomId: roomId, isLocked: isLocked);

  @override
  Stream<Room?> watchRoom(String roomId) =>
      _datasource.watchRoom(roomId).map((m) => m?.toEntity());

  @override
  Stream<String?> watch1v1Match(String uid) => _datasource.watch1v1Match(uid);
}
