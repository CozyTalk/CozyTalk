import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/avatar/domain/entities/avatar_decoration.dart';
import 'package:mobile/features/avatar/domain/usecases/get_cached_decoration.dart';

import '../shared_fakes.dart';

void main() {
  late FakeAvatarRepository repo;
  late GetCachedDecoration usecase;

  setUp(() {
    repo = FakeAvatarRepository();
    usecase = GetCachedDecoration(repo);
  });

  group('GetCachedDecoration', () {
    test('forwards uid to repository', () async {
      repo.returnCachedDecoration = const AvatarDecoration(hatKey: 'Crown');
      await usecase('u1');
      expect(repo.getCachedDecorationCount, 1);
      expect(repo.lastUid, 'u1');
    });

    test('returns decoration from repository', () async {
      const decoration = AvatarDecoration(hatKey: 'Crown', moodKey: 'Happy');
      repo.returnCachedDecoration = decoration;
      final result = await usecase('u1');
      expect(result?.hatKey, 'Crown');
      expect(result?.moodKey, 'Happy');
    });

    test('returns null on cache miss', () async {
      repo.returnCachedDecoration = null;
      final result = await usecase('u1');
      expect(result, isNull);
    });
  });
}
