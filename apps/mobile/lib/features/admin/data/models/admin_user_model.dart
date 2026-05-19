import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/entities/admin_ban_record.dart';
import '../../domain/entities/admin_user.dart';
import 'timestamp_converter.dart';

part 'admin_user_model.freezed.dart';
part 'admin_user_model.g.dart';

@freezed
abstract class AdminBanRecordModel with _$AdminBanRecordModel {
  const factory AdminBanRecordModel({
    required String reason,
    required String duration,
    @TimestampConverter() required DateTime bannedAt,
    @NullableTimestampConverter() DateTime? expiresAt,
    required String bannedBy,
    required String bannedByName,
    String? note,
    @NullableTimestampConverter() DateTime? unbannedAt,
    String? unbannedBy,
  }) = _AdminBanRecordModel;

  factory AdminBanRecordModel.fromJson(Map<String, dynamic> json) =>
      _$AdminBanRecordModelFromJson(json);
}

extension AdminBanRecordModelX on AdminBanRecordModel {
  AdminBanRecord toEntity() => AdminBanRecord(
    reason: reason,
    duration: duration,
    bannedAt: bannedAt,
    expiresAt: expiresAt,
    bannedByName: bannedByName,
    note: note,
    unbannedAt: unbannedAt,
    unbannedBy: unbannedBy,
  );
}

@freezed
abstract class AdminUserModel with _$AdminUserModel {
  const factory AdminUserModel({
    required String uid,
    required String displayName,
    String? email,
    @Default('') String interest,
    @Default(false) bool banned,
    @Default(false) bool online,
    @TimestampConverter() required DateTime createdAt,
    String? banReason,
    String? banDuration,
    @NullableTimestampConverter() DateTime? bannedAt,
    @NullableTimestampConverter() DateTime? banExpiresAt,
    String? bannedByName,
    String? banNote,
    @Default([]) List<AdminBanRecordModel> banHistory,
  }) = _AdminUserModel;

  factory AdminUserModel.fromJson(Map<String, dynamic> json) =>
      _$AdminUserModelFromJson(json);
}

extension AdminUserModelX on AdminUserModel {
  AdminUser toEntity() => AdminUser(
    uid: uid,
    displayName: displayName,
    email: email,
    interest: interest,
    banned: banned,
    online: online,
    createdAt: createdAt,
    banReason: banReason,
    banDuration: banDuration,
    bannedAt: bannedAt,
    banExpiresAt: banExpiresAt,
    bannedByName: bannedByName,
    banNote: banNote,
    banHistory: banHistory.map((r) => r.toEntity()).toList(),
  );
}
