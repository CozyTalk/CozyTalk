import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/entities/friend.dart';

part 'friend_model.freezed.dart';
part 'friend_model.g.dart';

@freezed
abstract class FriendModel with _$FriendModel {
  const factory FriendModel({
    required String id,
    required List<String> users,
    required Map<String, String> displayNames,
    required String chatRoomId,
    required int createdAt,
  }) = _FriendModel;

  factory FriendModel.fromJson(Map<String, dynamic> json) =>
      _$FriendModelFromJson(json);
}

extension FriendModelX on FriendModel {
  Friend toEntity(String currentUid) {
    final friendUid = users.firstWhere(
      (uid) => uid != currentUid,
      orElse: () => '',
    );
    return Friend(
      friendshipId: id,
      friendUid: friendUid,
      friendDisplayName: displayNames[friendUid] ?? 'Anonymous',
      chatRoomId: chatRoomId,
      friendedAt: DateTime.fromMillisecondsSinceEpoch(createdAt),
    );
  }
}
