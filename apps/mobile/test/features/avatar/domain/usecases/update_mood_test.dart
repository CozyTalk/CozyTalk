import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/avatar/domain/usecases/update_mood.dart';
import '../shared_fakes.dart';

void main() {
  late FakeAvatarRepository repo;
  late UpdateMood usecase;

  setUp(() {
    repo = FakeAvatarRepository();
    usecase = UpdateMood(repo);
  });

  group('UpdateMood', () {
    test('passes uid and moodKey to repository', () async {
      await usecase('u1', 'Happy');
      expect(repo.updateMoodCount, 1);
      expect(repo.lastUid, 'u1');
      expect(repo.lastMoodKey, 'Happy');
    });

    test('passes null moodKey to repository', () async {
      await usecase('u1', null);
      expect(repo.updateMoodCount, 1);
      expect(repo.lastMoodKey, isNull);
    });

    test('propagates repository exceptions', () {
      repo.error = Exception('permission denied');
      expect(() => usecase('u1', 'Grumpy'), throwsA(isA<Exception>()));
    });
  });
}
