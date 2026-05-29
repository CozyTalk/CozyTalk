import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/profile/domain/entities/profile_user.dart';
import 'package:mobile/features/profile/domain/usecases/get_cached_profile.dart';

import '../shared_fakes.dart';

void main() {
  late FakeProfileRepository repo;
  late GetCachedProfile usecase;

  setUp(() {
    repo = FakeProfileRepository();
    usecase = GetCachedProfile(repo);
  });

  group('GetCachedProfile', () {
    test('forwards uid to repository', () async {
      repo.returnCachedProfile = const ProfileUser(uid: 'u1');
      await usecase('u1');
      expect(repo.getCachedProfileCount, 1);
      expect(repo.lastUid, 'u1');
    });

    test('returns user from repository', () async {
      const user = ProfileUser(uid: 'u1', displayName: 'CachedAlice');
      repo.returnCachedProfile = user;
      final result = await usecase('u1');
      expect(result?.uid, 'u1');
      expect(result?.displayName, 'CachedAlice');
    });

    test('returns null when repository returns null', () async {
      repo.returnCachedProfile = null;
      final result = await usecase('u1');
      expect(result, isNull);
    });
  });
}
