import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/jukebox/domain/usecases/skip_track.dart';

import '../../shared_fakes.dart';

void main() {
  late FakeJukeboxRepository repo;
  late SkipTrack usecase;

  setUp(() {
    repo = FakeJukeboxRepository();
    usecase = SkipTrack(repo);
  });

  test(
    'advances currentIndex and sets isPlaying true with new startedAt',
    () async {
      final current = makeRoomState(
        currentIndex: 0,
        startedAt: 1000,
        queue: [
          makeTrack(id: '1'),
          makeTrack(id: '2'),
        ],
      );

      await usecase(roomId: 'room1', current: current);

      expect(repo.writeCount, 1);
      expect(repo.lastWrittenState?.currentIndex, 1);
      expect(repo.lastWrittenState?.isPlaying, isTrue);
      expect(repo.lastWrittenState?.startedAt, isNot(1000));
    },
  );

  test('calls clearJukebox when no next track', () async {
    final current = makeRoomState(
      currentIndex: 1,
      queue: [
        makeTrack(id: '1'),
        makeTrack(id: '2'),
      ],
    );

    await usecase(roomId: 'room1', current: current);

    expect(repo.clearCount, 1);
    expect(repo.writeCount, 0);
  });

  test('clears when queue is empty', () async {
    final current = makeRoomState();
    await usecase(roomId: 'room1', current: current);
    expect(repo.clearCount, 1);
  });
}
