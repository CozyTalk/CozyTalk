import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/avatar/domain/usecases/update_hat.dart';
import '../shared_fakes.dart';

void main() {
  late FakeAvatarRepository repo;
  late UpdateHat usecase;

  setUp(() {
    repo = FakeAvatarRepository();
    usecase = UpdateHat(repo);
  });

  group('UpdateHat', () {
    test('passes uid and hatKey to repository', () async {
      await usecase('u1', 'Crown');
      expect(repo.updateHatCount, 1);
      expect(repo.lastUid, 'u1');
      expect(repo.lastHatKey, 'Crown');
    });

    test('passes null hatKey to repository', () async {
      await usecase('u1', null);
      expect(repo.updateHatCount, 1);
      expect(repo.lastHatKey, isNull);
    });

    test('propagates repository exceptions', () {
      repo.error = Exception('permission denied');
      expect(() => usecase('u1', 'Cap'), throwsA(isA<Exception>()));
    });
  });
}
