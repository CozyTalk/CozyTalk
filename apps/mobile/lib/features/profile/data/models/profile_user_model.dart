import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/entities/profile_user.dart';

part 'profile_user_model.freezed.dart';
part 'profile_user_model.g.dart';

@freezed
abstract class ProfileUserModel with _$ProfileUserModel {
  const factory ProfileUserModel({
    required String uid,
    String? displayName,
    String? interest,
    String? thoughts,
  }) = _ProfileUserModel;

  factory ProfileUserModel.fromJson(Map<String, dynamic> json) =>
      _$ProfileUserModelFromJson(json);
}

extension ProfileUserModelX on ProfileUserModel {
  ProfileUser toEntity() => ProfileUser(
    uid: uid,
    displayName: displayName,
    interest: interest,
    thoughts: thoughts,
  );
}
