import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/admin/domain/entities/admin_report.dart';
import 'package:mobile/features/admin/domain/usecases/watch_reports.dart';
import '../shared_fakes.dart';

void main() {
  late FakeAdminRepository repo;
  late WatchReports usecase;

  setUp(() {
    repo = FakeAdminRepository();
    usecase = WatchReports(repo);
  });

  group('WatchReports', () {
    test('returns stream from repository', () async {
      final report = AdminReport(
        id: 'r1',
        status: 'pending',
        reporterId: 'u1',
        reportedUserId: 'u2',
        sessionId: 's1',
        reportType: 'spam',
        reason: 'Scam',
        createdAt: DateTime(2025, 1, 1),
        reporterName: 'Alice',
        reportedName: 'Bob',
        reportedInterest: '',
      );
      repo.returnReports = [report];
      final list = await usecase().first;
      expect(repo.watchReportsCount, 1);
      expect(list.length, 1);
      expect(list.first.id, 'r1');
    });

    test('returns empty list when repository returns empty', () async {
      repo.returnReports = [];
      final list = await usecase().first;
      expect(list, isEmpty);
    });

    test('propagates repository stream error', () {
      repo.error = Exception('permission denied');
      expect(usecase(), emitsError(isA<Exception>()));
    });
  });
}
