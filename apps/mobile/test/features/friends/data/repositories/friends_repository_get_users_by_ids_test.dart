import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/friends/data/datasources/friends_datasource.dart';
import 'package:mobile/features/friends/data/models/app_user_model.dart';
import 'package:mobile/features/friends/data/models/friend_message_model.dart';
import 'package:mobile/features/friends/data/models/friend_model.dart';
import 'package:mobile/features/friends/data/models/friend_request_model.dart';
import 'package:mobile/features/friends/data/repositories/friends_repository_impl.dart';
import 'package:mobile/features/friends/domain/entities/app_user.dart';
import 'package:mobile/features/friends/domain/entities/friend_room_status.dart';

class _FakeDatasource implements FriendsDatasource {
  List<AppUser> usersByIdResult = [];
  List<String>? lastGetUsersByIds;
  Exception? error;

  @override
  String get currentUid => 'current-uid';

  @override
  Stream<List<AppUserModel>> watchAllUsers() => Stream.value([]);

  @override
  Stream<List<FriendModel>> watchFriends() => Stream.value([]);

  @override
  Stream<List<FriendRequestModel>> watchIncomingRequests() => Stream.value([]);

  @override
  Stream<List<FriendMessageModel>> watchMessages(String chatRoomId) =>
      Stream.value([]);

  @override
  Stream<bool> watchFriendPresence(String friendUid) => Stream.value(false);

  @override
  Stream<String> watchFriendLastMessage(String chatRoomId) => Stream.value('');

  @override
  Stream<FriendRoomStatus?> watchFriendRoom(String friendUid) =>
      Stream.value(null);

  @override
  Future<void> sendFriendRequest({
    required String toUid,
    required String toDisplayName,
    required String fromDisplayName,
  }) async {}

  @override
  Future<void> acceptFriendRequest({
    required String requestId,
    required String fromUid,
    required String fromDisplayName,
    required String myDisplayName,
  }) async {}

  @override
  Future<void> declineFriendRequest({required String requestId}) async {}

  @override
  Future<void> removeFriend({required String friendshipId}) async {}

  @override
  Future<void> sendMessage({
    required String chatRoomId,
    required String text,
    required String senderDisplayName,
  }) async {}

  @override
  Future<void> setFriendTyping(String chatRoomId, bool isTyping) async {}

  @override
  Stream<bool> watchFriendTyping(String chatRoomId) => Stream.value(false);

  @override
  Future<List<AppUser>> getUsersByIds(List<String> uids) async {
    if (error != null) throw error!;
    lastGetUsersByIds = uids;
    return usersByIdResult;
  }
}

void main() {
  group('FriendsRepositoryImpl.getUsersByIds', () {
    test('delegates uid list to datasource', () async {
      final ds = _FakeDatasource()
        ..usersByIdResult = [const AppUser(uid: 'u1', displayName: 'Alice')];
      final repo = FriendsRepositoryImpl(ds);
      await repo.getUsersByIds(['u1']);
      expect(ds.lastGetUsersByIds, ['u1']);
    });

    test('returns AppUser list from datasource', () async {
      final ds = _FakeDatasource()
        ..usersByIdResult = [
          const AppUser(uid: 'u2', displayName: 'Bob'),
          const AppUser(uid: 'u3', displayName: 'Carol'),
        ];
      final repo = FriendsRepositoryImpl(ds);
      final result = await repo.getUsersByIds(['u2', 'u3']);
      expect(result, hasLength(2));
      expect(result[0].uid, 'u2');
      expect(result[1].uid, 'u3');
    });

    test('returns empty list when datasource returns empty', () async {
      final ds = _FakeDatasource();
      final repo = FriendsRepositoryImpl(ds);
      final result = await repo.getUsersByIds([]);
      expect(result, isEmpty);
    });

    test('propagates datasource exception', () {
      final ds = _FakeDatasource()..error = Exception('Firestore error');
      final repo = FriendsRepositoryImpl(ds);
      expect(() => repo.getUsersByIds(['u1']), throwsA(isA<Exception>()));
    });
  });
}
