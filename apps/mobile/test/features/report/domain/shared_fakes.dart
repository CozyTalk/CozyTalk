import 'package:mobile/features/report/domain/entities/report_type.dart';
import 'package:mobile/features/report/domain/repositories/report_repository.dart';

class FakeReportRepository implements ReportRepository {
  int submitCount = 0;
  String? lastSessionId;
  String? lastReportedUserId;
  ReportType? lastReportType;
  String? lastReason;
  String? lastContextText;
  List<String>? lastImagePaths;
  Exception? error;

  @override
  Future<void> submitReport({
    required String sessionId,
    required String reportedUserId,
    required ReportType reportType,
    required String reason,
    String? contextText,
    List<String> contextImagePaths = const [],
  }) async {
    submitCount++;
    lastSessionId = sessionId;
    lastReportedUserId = reportedUserId;
    lastReportType = reportType;
    lastReason = reason;
    lastContextText = contextText;
    lastImagePaths = contextImagePaths;
    if (error != null) throw error!;
  }
}
