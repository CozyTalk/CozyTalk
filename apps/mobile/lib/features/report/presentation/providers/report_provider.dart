import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/report_datasource.dart';
import '../../data/repositories/report_repository_impl.dart';
import '../../domain/entities/report_type.dart';
import '../../domain/repositories/report_repository.dart';
import '../../domain/usecases/submit_report.dart';

final _reportDatasourceProvider = Provider<ReportDatasource>(
  (ref) => ReportDatasourceImpl(
    FirebaseStorage.instance,
    FirebaseFunctions.instanceFor(region: 'us-central1'),
    FirebaseAuth.instance,
  ),
);

final _reportRepositoryProvider = Provider<ReportRepository>(
  (ref) => ReportRepositoryImpl(ref.watch(_reportDatasourceProvider)),
);

final _submitReportProvider = Provider<SubmitReport>(
  (ref) => SubmitReport(ref.watch(_reportRepositoryProvider)),
);

final reportNotifierProvider = NotifierProvider<ReportNotifier, ReportState>(
  ReportNotifier.new,
);

const _sentinel = Object();

class ReportState {
  final bool isSubmitting;
  final bool isSuccess;
  final String? error;
  final ReportType? selectedType;
  final String reason;
  final String contextText;
  final List<String> contextImagePaths;

  const ReportState({
    this.isSubmitting = false,
    this.isSuccess = false,
    this.error,
    this.selectedType,
    this.reason = '',
    this.contextText = '',
    this.contextImagePaths = const [],
  });

  ReportState copyWith({
    bool? isSubmitting,
    bool? isSuccess,
    Object? error = _sentinel,
    Object? selectedType = _sentinel,
    String? reason,
    String? contextText,
    List<String>? contextImagePaths,
  }) => ReportState(
    isSubmitting: isSubmitting ?? this.isSubmitting,
    isSuccess: isSuccess ?? this.isSuccess,
    error: error == _sentinel ? this.error : error as String?,
    selectedType: selectedType == _sentinel
        ? this.selectedType
        : selectedType as ReportType?,
    reason: reason ?? this.reason,
    contextText: contextText ?? this.contextText,
    contextImagePaths: contextImagePaths ?? this.contextImagePaths,
  );
}

class ReportNotifier extends Notifier<ReportState> {
  @override
  ReportState build() => const ReportState();

  void reset() {
    state = const ReportState();
  }

  void selectType(ReportType type) {
    state = state.copyWith(selectedType: type);
  }

  void setReason(String reason) {
    state = state.copyWith(reason: reason);
  }

  void setContextText(String text) {
    state = state.copyWith(contextText: text);
  }

  void addImage(String path) {
    if (state.contextImagePaths.length >= 5) return;
    state = state.copyWith(
      contextImagePaths: [...state.contextImagePaths, path],
    );
  }

  void removeImage(int index) {
    final updated = List<String>.from(state.contextImagePaths)..removeAt(index);
    state = state.copyWith(contextImagePaths: updated);
  }

  Future<void> submit({
    required String sessionId,
    required String reportedUserId,
  }) async {
    if (state.isSubmitting) return;
    final type = state.selectedType;
    if (type == null || state.reason.trim().isEmpty) return;

    state = state.copyWith(isSubmitting: true, error: null);
    try {
      await ref.read(_submitReportProvider)(
        sessionId: sessionId,
        reportedUserId: reportedUserId,
        reportType: type,
        reason: state.reason.trim(),
        contextText: state.contextText.trim().isEmpty
            ? null
            : state.contextText.trim(),
        contextImagePaths: state.contextImagePaths,
      );
      state = state.copyWith(isSubmitting: false, isSuccess: true);
    } catch (e) {
      state = state.copyWith(isSubmitting: false, error: e.toString());
    }
  }
}
