import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/profile/domain/entities/profile_user.dart';
import 'package:mobile/features/profile/domain/usecases/get_profile.dart';
import '../shared_fakes.dart';

void main() {
  late FakeProfileRepository repo;
  late GetProfile usecase;

  setUp(() {
    repo = FakeProfileRepository();
    usecase = GetProfile(repo);
  });

  group('GetProfile', () {
    test('passes uid to repository', () async {
      repo.returnProfile = const ProfileUser(uid: 'u1');
      await usecase('u1');
      expect(repo.getProfileCount, 1);
      expect(repo.lastUid, 'u1');
    });

    test('returns the ProfileUser from repository', () async {
      repo.returnProfile = const ProfileUser(
        uid: 'u1',
        displayName: 'Alice',
        interest: 'coding',
        thoughts: 'happy',
      );
      final result = await usecase('u1');
      expect(result.uid, 'u1');
      expect(result.displayName, 'Alice');
      expect(result.interest, 'coding');
      expect(result.thoughts, 'happy');
    });

    test('propagates repository exceptions', () {
      repo.error = Exception('not found');
      expect(() => usecase('u1'), throwsA(isA<Exception>()));
    });
  });
}
