import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/admin/domain/usecases/unban_user.dart';
import '../shared_fakes.dart';

void main() {
  late FakeAdminRepository repo;
  late UnbanUser usecase;

  setUp(() {
    repo = FakeAdminRepository();
    usecase = UnbanUser(repo);
  });

  group('UnbanUser', () {
    test('calls repository with uid', () async {
      await usecase('u1');
      expect(repo.unbanUserCount, 1);
      expect(repo.lastUid, 'u1');
    });

    test('propagates repository exception', () {
      repo.error = Exception('not banned');
      expect(() => usecase('u1'), throwsA(isA<Exception>()));
    });
  });
}
