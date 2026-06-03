import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/jukebox/domain/usecases/remove_from_queue.dart';

import '../../shared_fakes.dart';

void main() {
  late FakeJukeboxRepository repo;
  late RemoveFromQueue usecase;

  setUp(() {
    repo = FakeJukeboxRepository();
    usecase = RemoveFromQueue(repo);
  });

  test('removes correct index from queue and returns updated state', () async {
    final current = makeRoomState(
      queue: [
        makeTrack(id: '1'),
        makeTrack(id: '2'),
        makeTrack(id: '3'),
      ],
    );

    final result = await usecase(roomId: 'room1', current: current, index: 1);

    expect(repo.writeCount, 1);
    final q = repo.lastWrittenState!.queue;
    expect(q.map((t) => t.id).toList(), ['1', '3']);
    expect(result?.queue.map((t) => t.id).toList(), ['1', '3']);
  });

  test('calls clearJukebox when last track removed and returns null', () async {
    final current = makeRoomState(queue: [makeTrack()]);

    final result = await usecase(roomId: 'room1', current: current, index: 0);

    expect(repo.clearCount, 1);
    expect(repo.writeCount, 0);
    expect(result, isNull);
  });

  test(
    'decrements currentIndex when removed index is before current',
    () async {
      final current = makeRoomState(
        currentIndex: 2,
        queue: [
          makeTrack(id: '1'),
          makeTrack(id: '2'),
          makeTrack(id: '3'),
        ],
      );

      await usecase(roomId: 'room1', current: current, index: 1);

      expect(repo.lastWrittenState?.currentIndex, 1);
    },
  );

  test('resets startedAt when removing current track', () async {
    final current = makeRoomState(
      currentIndex: 0,
      startedAt: 99999,
      queue: [
        makeTrack(id: '1'),
        makeTrack(id: '2'),
      ],
    );

    await usecase(roomId: 'room1', current: current, index: 0);

    expect(repo.lastWrittenState?.startedAt, isNot(99999));
  });

  test('preserves startedAt when removing non-current track', () async {
    final current = makeRoomState(
      currentIndex: 0,
      startedAt: 99999,
      queue: [
        makeTrack(id: '1'),
        makeTrack(id: '2'),
      ],
    );

    await usecase(roomId: 'room1', current: current, index: 1);

    expect(repo.lastWrittenState?.startedAt, 99999);
  });

  test('does nothing and returns null for out-of-bounds index', () async {
    final current = makeRoomState(queue: [makeTrack()]);
    final result = await usecase(roomId: 'room1', current: current, index: 5);
    expect(repo.writeCount, 0);
    expect(repo.clearCount, 0);
    expect(result, isNull);
  });
}
