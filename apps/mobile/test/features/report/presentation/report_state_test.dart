import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/report/domain/entities/report_type.dart';
import 'package:mobile/features/report/presentation/providers/report_provider.dart';

void main() {
  group('ReportState', () {
    test('initial state has sensible defaults', () {
      const state = ReportState();
      expect(state.isSubmitting, isFalse);
      expect(state.isSuccess, isFalse);
      expect(state.error, isNull);
      expect(state.selectedType, isNull);
      expect(state.reason, '');
      expect(state.contextText, '');
      expect(state.contextImagePaths, isEmpty);
    });

    test('copyWith preserves unset fields', () {
      const original = ReportState(
        reason: 'test reason',
        selectedType: ReportType.spam,
        contextImagePaths: ['/a.jpg'],
      );
      final updated = original.copyWith(isSubmitting: true);
      expect(updated.reason, 'test reason');
      expect(updated.selectedType, ReportType.spam);
      expect(updated.contextImagePaths, ['/a.jpg']);
      expect(updated.isSubmitting, isTrue);
    });

    test('copyWith clears error with explicit null', () {
      final withError = const ReportState().copyWith(error: 'oops');
      expect(withError.error, 'oops');
      final cleared = withError.copyWith(error: null);
      expect(cleared.error, isNull);
    });

    test('copyWith preserves error when not passed', () {
      final withError = const ReportState().copyWith(error: 'err');
      final updated = withError.copyWith(isSubmitting: false);
      expect(updated.error, 'err');
    });

    test('copyWith clears selectedType with explicit null', () {
      final withType = const ReportState().copyWith(
        selectedType: ReportType.spam,
      );
      expect(withType.selectedType, ReportType.spam);
      final cleared = withType.copyWith(selectedType: null);
      expect(cleared.selectedType, isNull);
    });

    test('copyWith preserves selectedType when not passed', () {
      final withType = const ReportState().copyWith(
        selectedType: ReportType.other,
      );
      final updated = withType.copyWith(reason: 'hi');
      expect(updated.selectedType, ReportType.other);
    });

    test('copyWith updates contextImagePaths', () {
      final updated = const ReportState().copyWith(
        contextImagePaths: ['/x.jpg', '/y.jpg'],
      );
      expect(updated.contextImagePaths, ['/x.jpg', '/y.jpg']);
    });
  });
}
