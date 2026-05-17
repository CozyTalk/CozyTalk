import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/report/domain/entities/report_type.dart';

void main() {
  group('ReportType', () {
    test('has four values', () {
      expect(
        ReportType.values,
        containsAll([
          ReportType.spam,
          ReportType.harassment,
          ReportType.inappropriateContent,
          ReportType.other,
        ]),
      );
      expect(ReportType.values.length, 4);
    });

    group('wireValue', () {
      test('spam', () => expect(ReportType.spam.wireValue, 'spam'));
      test(
        'harassment',
        () => expect(ReportType.harassment.wireValue, 'harassment'),
      );
      test(
        'inappropriateContent',
        () => expect(
          ReportType.inappropriateContent.wireValue,
          'inappropriate_content',
        ),
      );
      test('other', () => expect(ReportType.other.wireValue, 'other'));
    });

    group('displayName', () {
      test('spam', () => expect(ReportType.spam.displayName, 'Spam'));
      test(
        'harassment',
        () => expect(ReportType.harassment.displayName, 'Harassment'),
      );
      test(
        'inappropriateContent',
        () => expect(
          ReportType.inappropriateContent.displayName,
          'Inappropriate Content',
        ),
      );
      test('other', () => expect(ReportType.other.displayName, 'Other'));
    });
  });
}
