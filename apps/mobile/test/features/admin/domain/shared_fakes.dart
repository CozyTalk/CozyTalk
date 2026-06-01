import 'package:mobile/features/admin/domain/entities/admin_blocked_entry.dart';
import 'package:mobile/features/admin/domain/entities/admin_report.dart';
import 'package:mobile/features/admin/domain/entities/admin_user.dart';
import 'package:mobile/features/admin/domain/repositories/admin_repository.dart';

class FakeAdminRepository implements AdminRepository {
  int returnOnlineCount = 0;
  List<AdminReport>? returnReports;
  String? returnChatLogUrl;
  List<AdminUser>? returnUsers;
  Exception? error;

  int watchOnlineCountCount = 0;
  int watchReportsCount = 0;
  int resolveReportCount = 0;
  int getChatLogUrlCount = 0;
  int watchUsersCount = 0;
  int banUserCount = 0;
  int unbanUserCount = 0;

  String? lastReportId;
  String? lastAction;
  String? lastNote;
  String? lastUid;
  String? lastReason;
  String? lastDuration;
  String? lastBanNote;
  String? lastReportIdForBan;

  @override
  Stream<int> watchOnlineCount() {
    watchOnlineCountCount++;
    if (error != null) return Stream.error(error!);
    return Stream.value(returnOnlineCount);
  }

  @override
  Stream<int> watchPendingCount() => Stream.value(0);

  @override
  Stream<List<AdminReport>> watchReports() {
    watchReportsCount++;
    if (error != null) return Stream.error(error!);
    return Stream.value(returnReports ?? []);
  }

  @override
  Future<void> resolveReport(
    String reportId, {
    required String action,
    String? note,
  }) async {
    resolveReportCount++;
    lastReportId = reportId;
    lastAction = action;
    lastNote = note;
    if (error != null) throw error!;
  }

  @override
  Future<String> getChatLogUrl(String reportId) async {
    getChatLogUrlCount++;
    lastReportId = reportId;
    if (error != null) throw error!;
    return returnChatLogUrl!;
  }

  @override
  Stream<List<AdminUser>> watchUsers() {
    watchUsersCount++;
    if (error != null) return Stream.error(error!);
    return Stream.value(returnUsers ?? []);
  }

  @override
  Future<void> banUser({
    required String uid,
    required String reason,
    required String duration,
    String? note,
    String? reportId,
  }) async {
    banUserCount++;
    lastUid = uid;
    lastReason = reason;
    lastDuration = duration;
    lastBanNote = note;
    lastReportIdForBan = reportId;
    if (error != null) throw error!;
  }

  @override
  Future<void> unbanUser(String uid) async {
    unbanUserCount++;
    lastUid = uid;
    if (error != null) throw error!;
  }

  @override
  Future<List<AdminBlockedEntry>> getBlockedUsers(String uid) async {
    if (error != null) throw error!;
    return [];
  }
}
