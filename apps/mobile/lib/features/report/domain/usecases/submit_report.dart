import '../entities/report_type.dart';
import '../repositories/report_repository.dart';

class SubmitReport {
  final ReportRepository _repository;

  const SubmitReport(this._repository);

  Future<void> call({
    required String sessionId,
    required String reportedUserId,
    required ReportType reportType,
    required String reason,
    String? contextText,
    List<String> contextImagePaths = const [],
  }) => _repository.submitReport(
    sessionId: sessionId,
    reportedUserId: reportedUserId,
    reportType: reportType,
    reason: reason,
    contextText: contextText,
    contextImagePaths: contextImagePaths,
  );
}
