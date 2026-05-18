import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/entities/friend_message.dart';

part 'friend_message_model.freezed.dart';
part 'friend_message_model.g.dart';

@freezed
abstract class FriendMessageModel with _$FriendMessageModel {
  const factory FriendMessageModel({
    required String id,
    required String senderId,
    required String senderDisplayName,
    required String text,
    required int timestamp,
  }) = _FriendMessageModel;

  factory FriendMessageModel.fromJson(Map<String, dynamic> json) =>
      _$FriendMessageModelFromJson(json);
}

extension FriendMessageModelX on FriendMessageModel {
  FriendMessage toEntity() => FriendMessage(
    id: id,
    senderId: senderId,
    senderDisplayName: senderDisplayName,
    text: text,
    timestamp: DateTime.fromMillisecondsSinceEpoch(timestamp),
  );
}
