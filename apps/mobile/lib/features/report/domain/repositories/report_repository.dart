import '../entities/report_type.dart';

abstract class ReportRepository {
  Future<void> submitReport({
    required String sessionId,
    required String reportedUserId,
    required ReportType reportType,
    required String reason,
    String? contextText,
    List<String> contextImagePaths,
  });
}
