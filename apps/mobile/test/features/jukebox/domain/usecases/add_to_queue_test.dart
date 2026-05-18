import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/jukebox/domain/usecases/add_to_queue.dart';

import '../../shared_fakes.dart';

void main() {
  late FakeJukeboxRepository repo;
  late AddToQueue usecase;

  setUp(() {
    repo = FakeJukeboxRepository();
    usecase = AddToQueue(repo);
  });

  test('appends track to queue', () async {
    final existing = makeTrack(id: '1');
    final current = makeRoomState(isPlaying: true, queue: [existing]);
    final newTrack = makeTrack(id: '2');

    await usecase(roomId: 'room1', current: current, track: newTrack);

    expect(repo.writeCount, 1);
    expect(repo.lastWrittenState?.queue.length, 2);
    expect(repo.lastWrittenState?.queue.last.id, '2');
  });

  test('first track sets isPlaying true and non-zero startedAt', () async {
    final current = makeRoomState();
    final track = makeTrack();

    await usecase(roomId: 'room1', current: current, track: track);

    expect(repo.lastWrittenState?.isPlaying, isTrue);
    expect(repo.lastWrittenState?.startedAt, isNot(0));
  });

  test(
    'does not change isPlaying or startedAt when queue already has tracks',
    () async {
      final t1 = makeTrack(id: '1');
      final current = makeRoomState(
        isPlaying: false,
        startedAt: 12345,
        queue: [t1],
      );
      final newTrack = makeTrack(id: '2');

      await usecase(roomId: 'room1', current: current, track: newTrack);

      expect(repo.lastWrittenState?.isPlaying, isFalse);
      expect(repo.lastWrittenState?.startedAt, 12345);
    },
  );

  test('throws when queue already has 4 tracks', () async {
    final current = makeRoomState(
      queue: [
        makeTrack(id: '1'),
        makeTrack(id: '2'),
        makeTrack(id: '3'),
        makeTrack(id: '4'),
      ],
    );

    expect(
      () => usecase(
        roomId: 'room1',
        current: current,
        track: makeTrack(id: '5'),
      ),
      throwsException,
    );
    expect(repo.writeCount, 0);
  });
}
