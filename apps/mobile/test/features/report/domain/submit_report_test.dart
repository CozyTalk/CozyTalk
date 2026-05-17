import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/report/domain/entities/report_type.dart';
import 'package:mobile/features/report/domain/usecases/submit_report.dart';

import 'shared_fakes.dart';

void main() {
  late FakeReportRepository repo;
  late SubmitReport useCase;

  setUp(() {
    repo = FakeReportRepository();
    useCase = SubmitReport(repo);
  });

  test('forwards all required arguments to repository', () async {
    await useCase(
      sessionId: 'ses1',
      reportedUserId: 'user2',
      reportType: ReportType.spam,
      reason: 'Sending spam',
    );

    expect(repo.submitCount, 1);
    expect(repo.lastSessionId, 'ses1');
    expect(repo.lastReportedUserId, 'user2');
    expect(repo.lastReportType, ReportType.spam);
    expect(repo.lastReason, 'Sending spam');
    expect(repo.lastContextText, isNull);
    expect(repo.lastImagePaths, isEmpty);
  });

  test('forwards optional contextText and image paths', () async {
    await useCase(
      sessionId: 'ses1',
      reportedUserId: 'user2',
      reportType: ReportType.harassment,
      reason: 'Harassing me',
      contextText: 'Here is more detail',
      contextImagePaths: ['/tmp/a.jpg', '/tmp/b.jpg'],
    );

    expect(repo.lastContextText, 'Here is more detail');
    expect(repo.lastImagePaths, ['/tmp/a.jpg', '/tmp/b.jpg']);
  });

  test('propagates repository exception', () async {
    repo.error = Exception('network error');
    expect(
      () => useCase(
        sessionId: 's',
        reportedUserId: 'u',
        reportType: ReportType.other,
        reason: 'reason',
      ),
      throwsException,
    );
  });
}
