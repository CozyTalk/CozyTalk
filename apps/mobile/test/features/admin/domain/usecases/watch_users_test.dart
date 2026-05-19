import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/admin/domain/entities/admin_user.dart';
import 'package:mobile/features/admin/domain/usecases/watch_users.dart';
import '../shared_fakes.dart';

void main() {
  late FakeAdminRepository repo;
  late WatchUsers usecase;

  setUp(() {
    repo = FakeAdminRepository();
    usecase = WatchUsers(repo);
  });

  group('WatchUsers', () {
    test('returns stream of users from repository', () async {
      final user = AdminUser(
        uid: 'u1',
        displayName: 'Alice',
        interest: 'gaming',
        banned: false,
        online: true,
        createdAt: DateTime(2024, 1, 1),
      );
      repo.returnUsers = [user];
      final list = await usecase().first;
      expect(repo.watchUsersCount, 1);
      expect(list.length, 1);
      expect(list.first.uid, 'u1');
    });

    test('returns empty list when repository returns empty', () async {
      repo.returnUsers = [];
      final list = await usecase().first;
      expect(list, isEmpty);
    });

    test('propagates repository stream error', () {
      repo.error = Exception('permission denied');
      expect(usecase(), emitsError(isA<Exception>()));
    });
  });
}
