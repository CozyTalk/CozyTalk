import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/admin/domain/usecases/ban_user.dart';
import '../shared_fakes.dart';

void main() {
  late FakeAdminRepository repo;
  late BanUser usecase;

  setUp(() {
    repo = FakeAdminRepository();
    usecase = BanUser(repo);
  });

  group('BanUser', () {
    test('forwards all required args to repository', () async {
      await usecase(uid: 'u1', reason: 'Spam', duration: '7 Days');
      expect(repo.banUserCount, 1);
      expect(repo.lastUid, 'u1');
      expect(repo.lastReason, 'Spam');
      expect(repo.lastDuration, '7 Days');
      expect(repo.lastBanNote, isNull);
      expect(repo.lastReportIdForBan, isNull);
    });

    test('forwards optional note and reportId', () async {
      await usecase(
        uid: 'u2',
        reason: 'Harassment',
        duration: 'Permanent',
        note: 'Very serious',
        reportId: 'r1',
      );
      expect(repo.lastBanNote, 'Very serious');
      expect(repo.lastReportIdForBan, 'r1');
    });

    test('propagates repository exception', () {
      repo.error = Exception('already banned');
      expect(
        () => usecase(uid: 'u1', reason: 'Spam', duration: '1 Day'),
        throwsA(isA<Exception>()),
      );
    });
  });
}
