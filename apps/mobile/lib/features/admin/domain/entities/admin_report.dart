import 'admin_report_outcome.dart';

class AdminReport {
  final String id;
  final String status; // "pending" | "resolved"
  final String reporterId;
  final String reportedUserId;
  final String sessionId;
  final String reportType; // "spam" | "harassment" | "inappropriate_content" | "other"
  final String reason;
  final String? contextText;
  final List<String> contextImageUrls;
  final String? chatLogStoragePath;
  final DateTime createdAt;
  final AdminReportOutcome? outcome;
  final String reporterName;
  final String reportedName;
  final String reportedInterest;

  const AdminReport({
    required this.id,
    required this.status,
    required this.reporterId,
    required this.reportedUserId,
    required this.sessionId,
    required this.reportType,
    required this.reason,
    this.contextText,
    this.contextImageUrls = const [],
    this.chatLogStoragePath,
    required this.createdAt,
    this.outcome,
    required this.reporterName,
    required this.reportedName,
    required this.reportedInterest,
  });
}
