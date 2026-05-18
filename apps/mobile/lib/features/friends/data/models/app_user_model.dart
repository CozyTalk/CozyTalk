import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/entities/app_user.dart';

part 'app_user_model.freezed.dart';
part 'app_user_model.g.dart';

@freezed
abstract class AppUserModel with _$AppUserModel {
  const factory AppUserModel({
    required String uid,
    required String displayName,
  }) = _AppUserModel;

  factory AppUserModel.fromJson(Map<String, dynamic> json) =>
      _$AppUserModelFromJson(json);
}

extension AppUserModelX on AppUserModel {
  AppUser toEntity() => AppUser(uid: uid, displayName: displayName);
}
