import '../entities/room.dart';

abstract class MatchmakingRepository {
  Future<({String roomId, bool isNewRoom})> joinGroupRoom({
    String? interestText,
  });
  Future<String> createCustomRoom();
  Future<({String roomId, RoomMode mode, RoomType roomType})> joinRoomById(
    String roomId,
  );
  Future<void> leaveRoom(String roomId);
  Future<void> join1v1Pool({String? interestText});
  Future<bool> cancel1v1Pool();
  Future<void> setRoomLock({required String roomId, required bool isLocked});
  Stream<Room?> watchRoom(String roomId);
  Stream<String?> watch1v1Match(String uid);
}
