import '../../domain/entities/app_user.dart';
import '../../domain/entities/friend.dart';
import '../../domain/entities/friend_message.dart';
import '../../domain/entities/friend_request.dart';
import '../../domain/entities/friend_room_status.dart';
import '../../domain/repositories/friends_repository.dart';
import '../datasources/friends_datasource.dart';
import '../models/app_user_model.dart';
import '../models/friend_message_model.dart';
import '../models/friend_model.dart';
import '../models/friend_request_model.dart';

class FriendsRepositoryImpl implements FriendsRepository {
  final FriendsDatasource _datasource;

  FriendsRepositoryImpl(this._datasource);

  @override
  Stream<List<AppUser>> watchAllUsers() => _datasource.watchAllUsers().map(
    (models) => models.map((m) => m.toEntity()).toList(),
  );

  @override
  Stream<List<Friend>> watchFriends() => _datasource.watchFriends().map(
    (models) => models.map((m) => m.toEntity(_datasource.currentUid)).toList(),
  );

  @override
  Stream<List<FriendRequest>> watchIncomingRequests() => _datasource
      .watchIncomingRequests()
      .map((models) => models.map((m) => m.toEntity()).toList());

  @override
  Stream<List<FriendMessage>> watchMessages(String chatRoomId) => _datasource
      .watchMessages(chatRoomId)
      .map((models) => models.map((m) => m.toEntity()).toList());

  @override
  Stream<bool> watchFriendPresence(String friendUid) =>
      _datasource.watchFriendPresence(friendUid);

  @override
  Stream<({String text, DateTime? timestamp, String senderId})>
  watchFriendLastMessage(String chatRoomId) =>
      _datasource.watchFriendLastMessage(chatRoomId);

  @override
  Stream<FriendRoomStatus?> watchFriendRoom(String friendUid) =>
      _datasource.watchFriendRoom(friendUid);

  @override
  Future<void> sendFriendRequest({
    required String toUid,
    required String toDisplayName,
    required String fromDisplayName,
  }) => _datasource.sendFriendRequest(
    toUid: toUid,
    toDisplayName: toDisplayName,
    fromDisplayName: fromDisplayName,
  );

  @override
  Future<void> acceptFriendRequest({
    required String requestId,
    required String fromUid,
    required String fromDisplayName,
    required String myDisplayName,
  }) => _datasource.acceptFriendRequest(
    requestId: requestId,
    fromUid: fromUid,
    fromDisplayName: fromDisplayName,
    myDisplayName: myDisplayName,
  );

  @override
  Future<void> declineFriendRequest({required String requestId}) =>
      _datasource.declineFriendRequest(requestId: requestId);

  @override
  Future<void> undoAcceptFriendRequest({
    required String requestId,
    required String friendshipId,
  }) => _datasource.undoAcceptFriendRequest(
    requestId: requestId,
    friendshipId: friendshipId,
  );

  @override
  Future<void> undoDeclineFriendRequest({required String requestId}) =>
      _datasource.undoDeclineFriendRequest(requestId: requestId);

  @override
  Future<void> removeFriend({required String friendshipId}) =>
      _datasource.removeFriend(friendshipId: friendshipId);

  @override
  Future<void> sendMessage({
    required String chatRoomId,
    required String text,
    required String senderDisplayName,
  }) => _datasource.sendMessage(
    chatRoomId: chatRoomId,
    text: text,
    senderDisplayName: senderDisplayName,
  );

  @override
  Future<List<AppUser>> getUsersByIds(List<String> uids) =>
      _datasource.getUsersByIds(uids);

  @override
  Future<int> getUnreadMessageCount(
    String chatRoomId, {
    required int sinceMs,
    required String friendUid,
  }) => _datasource.getUnreadMessageCount(
    chatRoomId,
    sinceMs: sinceMs,
    friendUid: friendUid,
  );

  @override
  Future<void> setChatRead(String chatRoomId) =>
      _datasource.setChatRead(chatRoomId);

  @override
  Stream<DateTime?> watchChatRead(String chatRoomId) =>
      _datasource.watchChatRead(chatRoomId);

  @override
  Future<void> setFriendTyping(String chatRoomId, bool isTyping) =>
      _datasource.setFriendTyping(chatRoomId, isTyping);

  @override
  Stream<bool> watchFriendTyping(String chatRoomId) =>
      _datasource.watchFriendTyping(chatRoomId);
}
