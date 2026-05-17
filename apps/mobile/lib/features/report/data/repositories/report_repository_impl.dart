import '../../domain/entities/report_type.dart';
import '../../domain/repositories/report_repository.dart';
import '../datasources/report_datasource.dart';

class ReportRepositoryImpl implements ReportRepository {
  final ReportDatasource _datasource;

  const ReportRepositoryImpl(this._datasource);

  @override
  Future<void> submitReport({
    required String sessionId,
    required String reportedUserId,
    required ReportType reportType,
    required String reason,
    String? contextText,
    List<String> contextImagePaths = const [],
  }) => _datasource.submitReport(
    sessionId: sessionId,
    reportedUserId: reportedUserId,
    reportType: reportType.wireValue,
    reason: reason,
    contextText: contextText,
    contextImagePaths: contextImagePaths,
  );
}
