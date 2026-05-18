import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/entities/friend_request.dart';

part 'friend_request_model.freezed.dart';
part 'friend_request_model.g.dart';

@freezed
abstract class FriendRequestModel with _$FriendRequestModel {
  const factory FriendRequestModel({
    required String id,
    required String fromUid,
    required String fromDisplayName,
    required String toUid,
    required String toDisplayName,
    required String status,
    required int createdAt,
  }) = _FriendRequestModel;

  factory FriendRequestModel.fromJson(Map<String, dynamic> json) =>
      _$FriendRequestModelFromJson(json);
}

extension FriendRequestModelX on FriendRequestModel {
  FriendRequest toEntity() => FriendRequest(
    id: id,
    fromUid: fromUid,
    fromDisplayName: fromDisplayName,
    toUid: toUid,
    toDisplayName: toDisplayName,
    status: _parseStatus(status),
    createdAt: DateTime.fromMillisecondsSinceEpoch(createdAt),
  );

  static FriendRequestStatus _parseStatus(String s) => switch (s) {
    'accepted' => FriendRequestStatus.accepted,
    'declined' => FriendRequestStatus.declined,
    _ => FriendRequestStatus.pending,
  };
}
