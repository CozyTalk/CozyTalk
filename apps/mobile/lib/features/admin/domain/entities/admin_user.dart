import 'admin_ban_record.dart';

class AdminUser {
  final String uid;
  final String displayName;
  final String? email;
  final String interest;
  final bool banned;
  final bool online;
  final DateTime createdAt;
  final String? banReason;
  final String? banDuration;
  final DateTime? bannedAt;
  final DateTime? banExpiresAt;
  final String? bannedByName;
  final String? banNote;
  final List<AdminBanRecord> banHistory;

  const AdminUser({
    required this.uid,
    required this.displayName,
    this.email,
    required this.interest,
    required this.banned,
    required this.online,
    required this.createdAt,
    this.banReason,
    this.banDuration,
    this.bannedAt,
    this.banExpiresAt,
    this.bannedByName,
    this.banNote,
    this.banHistory = const [],
  });
}
