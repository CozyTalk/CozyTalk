import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/admin/domain/usecases/resolve_report.dart';
import '../shared_fakes.dart';

void main() {
  late FakeAdminRepository repo;
  late ResolveReport usecase;

  setUp(() {
    repo = FakeAdminRepository();
    usecase = ResolveReport(repo);
  });

  group('ResolveReport', () {
    test('calls repository with reportId and action', () async {
      await usecase('r1', action: 'dismiss');
      expect(repo.resolveReportCount, 1);
      expect(repo.lastReportId, 'r1');
      expect(repo.lastAction, 'dismiss');
      expect(repo.lastNote, isNull);
    });

    test('passes optional note to repository', () async {
      await usecase('r2', action: 'reviewed', note: 'Looks valid');
      expect(repo.lastReportId, 'r2');
      expect(repo.lastAction, 'reviewed');
      expect(repo.lastNote, 'Looks valid');
    });

    test('propagates repository exception', () {
      repo.error = Exception('not found');
      expect(() => usecase('r3', action: 'dismiss'), throwsA(isA<Exception>()));
    });
  });
}
