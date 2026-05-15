import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/matchmaking/domain/usecases/watch_room.dart';

import '../shared_fakes.dart';

void main() {
  group('WatchRoom', () {
    late FakeMatchmakingRepository repo;
    late WatchRoom useCase;

    setUp(() {
      repo = FakeMatchmakingRepository();
      useCase = WatchRoom(repo);
    });

    test('returns the stream from repository with room value', () async {
      final room = makeRoom(roomId: 'WtRm7');
      repo.watchRoomValue = room;

      final stream = useCase('WtRm7');

      expect(await stream.first, room);
    });

    test('returns null when repository emits null', () async {
      repo.watchRoomValue = null;

      final stream = useCase('WtRm7');

      expect(await stream.first, isNull);
    });
  });
}
