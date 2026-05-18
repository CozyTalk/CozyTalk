import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/entities/admin_report.dart';
import '../../domain/entities/admin_report_outcome.dart';
import 'timestamp_converter.dart';

part 'admin_report_model.freezed.dart';
part 'admin_report_model.g.dart';

@freezed
abstract class AdminReportOutcomeModel with _$AdminReportOutcomeModel {
  const factory AdminReportOutcomeModel({
    required String kind,
    required String byName,
    @TimestampConverter() required DateTime at,
    String? note,
  }) = _AdminReportOutcomeModel;

  factory AdminReportOutcomeModel.fromJson(Map<String, dynamic> json) =>
      _$AdminReportOutcomeModelFromJson(json);
}

extension AdminReportOutcomeModelX on AdminReportOutcomeModel {
  AdminReportOutcome toEntity() => AdminReportOutcome(
    kind: kind,
    byName: byName,
    at: at,
    note: note,
  );
}

@freezed
abstract class AdminReportModel with _$AdminReportModel {
  const factory AdminReportModel({
    required String id,
    required String reporterId,
    required String reportedUserId,
    required String sessionId,
    required String reportType,
    required String reason,
    String? contextText,
    @Default([]) List<String> contextImageUrls,
    String? chatLogStoragePath,
    @TimestampConverter() required DateTime createdAt,
    @Default('pending') String status,
    AdminReportOutcomeModel? outcome,
    @Default('Unknown') String reporterName,
    @Default('Unknown') String reportedName,
    @Default('') String reportedInterest,
  }) = _AdminReportModel;

  factory AdminReportModel.fromJson(Map<String, dynamic> json) =>
      _$AdminReportModelFromJson(json);
}

extension AdminReportModelX on AdminReportModel {
  AdminReport toEntity() => AdminReport(
    id: id,
    status: status == 'pending' ? 'pending' : 'resolved',
    reporterId: reporterId,
    reportedUserId: reportedUserId,
    sessionId: sessionId,
    reportType: reportType,
    reason: reason,
    contextText: contextText,
    contextImageUrls: contextImageUrls,
    chatLogStoragePath: chatLogStoragePath,
    createdAt: createdAt,
    outcome: outcome?.toEntity(),
    reporterName: reporterName,
    reportedName: reportedName,
    reportedInterest: reportedInterest,
  );
}
