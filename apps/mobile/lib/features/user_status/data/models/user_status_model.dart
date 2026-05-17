import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/entities/user_status.dart';

part 'user_status_model.freezed.dart';
part 'user_status_model.g.dart';

@freezed
abstract class UserStatusModel with _$UserStatusModel {
  const factory UserStatusModel({
    required String status,
    String? roomId,
    String? roomMode,
  }) = _UserStatusModel;

  factory UserStatusModel.fromJson(Map<String, dynamic> json) =>
      _$UserStatusModelFromJson(json);
}

extension UserStatusModelX on UserStatusModel {
  UserStatus toEntity(String uid) => UserStatus(
    uid: uid,
    status: status == 'in_room'
        ? UserOnlineStatus.inRoom
        : UserOnlineStatus.online,
    roomId: roomId,
    roomMode: roomMode,
  );
}
