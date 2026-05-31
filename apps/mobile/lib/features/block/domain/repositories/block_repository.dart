import '../entities/blocked_user.dart';

abstract class BlockRepository {
  Stream<List<BlockedUser>> watchBlockedUsers(String uid);
  Stream<bool> watchIsBlockedBy(String partnerUid, String myUid);
  Future<void> blockUser(
    String ownerUid,
    String targetUid, {
    String? displayName,
  });
  Future<void> unblockUser(String ownerUid, String targetUid);
}
