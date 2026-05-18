import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/jukebox/domain/usecases/set_playing.dart';

import '../../shared_fakes.dart';

void main() {
  late FakeJukeboxRepository repo;
  late SetPlaying usecase;

  setUp(() {
    repo = FakeJukeboxRepository();
    usecase = SetPlaying(repo);
  });

  test('sets isPlaying to true', () async {
    final current = makeRoomState(isPlaying: false, queue: [makeTrack()]);
    await usecase(roomId: 'room1', current: current, isPlaying: true);
    expect(repo.lastWrittenState?.isPlaying, isTrue);
  });

  test('sets isPlaying to false', () async {
    final current = makeRoomState(isPlaying: true, queue: [makeTrack()]);
    await usecase(roomId: 'room1', current: current, isPlaying: false);
    expect(repo.lastWrittenState?.isPlaying, isFalse);
  });

  test('resets startedAt when resuming from paused', () async {
    final current = makeRoomState(
      isPlaying: false,
      startedAt: 5000,
      queue: [makeTrack()],
    );
    await usecase(roomId: 'room1', current: current, isPlaying: true);
    expect(repo.lastWrittenState?.startedAt, isNot(5000));
  });

  test('preserves startedAt when pausing', () async {
    final current = makeRoomState(
      isPlaying: true,
      startedAt: 5000,
      queue: [makeTrack()],
    );
    await usecase(roomId: 'room1', current: current, isPlaying: false);
    expect(repo.lastWrittenState?.startedAt, 5000);
  });
}
