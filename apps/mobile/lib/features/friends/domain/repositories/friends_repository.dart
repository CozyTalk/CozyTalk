import '../entities/app_user.dart';
import '../entities/friend.dart';
import '../entities/friend_message.dart';
import '../entities/friend_request.dart';
import '../entities/friend_room_status.dart';

abstract class FriendsRepository {
  Stream<List<AppUser>> watchAllUsers();
  Stream<List<Friend>> watchFriends();
  Stream<List<FriendRequest>> watchIncomingRequests();
  Stream<List<FriendRequest>> watchOutgoingRequests();
  Stream<List<FriendMessage>> watchMessages(String chatRoomId);
  Stream<bool> watchFriendPresence(String friendUid);
  Stream<({String text, DateTime? timestamp, String senderId})>
  watchFriendLastMessage(String chatRoomId);
  Stream<FriendRoomStatus?> watchFriendRoom(String friendUid);
  Future<void> sendFriendRequest({
    required String toUid,
    required String toDisplayName,
    required String fromDisplayName,
  });
  Future<void> acceptFriendRequest({
    required String requestId,
    required String fromUid,
    required String fromDisplayName,
    required String myDisplayName,
  });
  Future<void> declineFriendRequest({required String requestId});
  Future<void> cancelFriendRequest({required String toUid});
  Future<void> removeFriend({required String friendshipId});
  Future<void> sendMessage({
    required String chatRoomId,
    required String text,
    required String senderDisplayName,
  });
  Future<List<AppUser>> getUsersByIds(List<String> uids);
  Future<int> getUnreadMessageCount(
    String chatRoomId, {
    required int sinceMs,
    required String friendUid,
  });
  Future<void> setChatRead(String chatRoomId);
  Stream<DateTime?> watchChatRead(String chatRoomId);
  Future<void> setFriendTyping(String chatRoomId, bool isTyping);
  Stream<bool> watchFriendTyping(String chatRoomId);
}
