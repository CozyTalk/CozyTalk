import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/matchmaking/domain/usecases/watch_1v1_match.dart';

import '../shared_fakes.dart';

void main() {
  group('Watch1v1Match', () {
    late FakeMatchmakingRepository repo;
    late Watch1v1Match useCase;

    setUp(() {
      repo = FakeMatchmakingRepository();
      useCase = Watch1v1Match(repo);
    });

    test('returns the matched roomId when available', () async {
      repo.watch1v1MatchValue = 'MtRm2';

      final stream = useCase('uid-alice');

      expect(await stream.first, 'MtRm2');
    });

    test('returns null when no match yet', () async {
      repo.watch1v1MatchValue = null;

      final stream = useCase('uid-alice');

      expect(await stream.first, isNull);
    });
  });
}
