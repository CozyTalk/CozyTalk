import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/avatar/domain/usecases/update_decoration.dart';
import '../shared_fakes.dart';

void main() {
  late FakeAvatarRepository repo;
  late UpdateDecoration usecase;

  setUp(() {
    repo = FakeAvatarRepository();
    usecase = UpdateDecoration(repo);
  });

  group('UpdateDecoration', () {
    test('passes uid, hatKey, and moodKey to repository', () async {
      await usecase('u1', 'Crown', 'Happy');
      expect(repo.updateDecorationCount, 1);
      expect(repo.lastUid, 'u1');
      expect(repo.lastHatKey, 'Crown');
      expect(repo.lastMoodKey, 'Happy');
    });

    test('passes null values to repository', () async {
      await usecase('u1', null, null);
      expect(repo.updateDecorationCount, 1);
      expect(repo.lastHatKey, isNull);
      expect(repo.lastMoodKey, isNull);
    });

    test('passes mixed null and non-null keys to repository', () async {
      await usecase('u1', 'Cap', null);
      expect(repo.lastHatKey, 'Cap');
      expect(repo.lastMoodKey, isNull);
    });

    test('propagates repository exceptions', () {
      repo.error = Exception('permission denied');
      expect(() => usecase('u1', 'Crown', 'Happy'), throwsA(isA<Exception>()));
    });
  });
}
