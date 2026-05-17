import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/avatar/domain/entities/avatar_decoration.dart';
import 'package:mobile/features/avatar/domain/usecases/get_avatar_decoration.dart';
import '../shared_fakes.dart';

void main() {
  late FakeAvatarRepository repo;
  late GetAvatarDecoration usecase;

  setUp(() {
    repo = FakeAvatarRepository();
    usecase = GetAvatarDecoration(repo);
  });

  group('GetAvatarDecoration', () {
    test('passes uid to repository', () async {
      await usecase('u1');
      expect(repo.getDecorationCount, 1);
      expect(repo.lastUid, 'u1');
    });

    test('returns the decoration from repository', () async {
      repo.returnDecoration = const AvatarDecoration(
        hatKey: 'Cap',
        moodKey: 'Happy',
      );
      final result = await usecase('u1');
      expect(result?.hatKey, 'Cap');
      expect(result?.moodKey, 'Happy');
    });

    test('returns null when repository returns null', () async {
      repo.returnDecoration = null;
      final result = await usecase('u1');
      expect(result, isNull);
    });

    test('propagates repository exceptions', () {
      repo.error = Exception('not found');
      expect(() => usecase('u1'), throwsA(isA<Exception>()));
    });
  });
}
