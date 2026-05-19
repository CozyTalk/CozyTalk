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
    await usecase(
      roomId: 'room1',
      current: current,
      isPlaying: true,
      pausedAt: 0,
    );
    expect(repo.lastWrittenState?.isPlaying, isTrue);
  });

  test('sets isPlaying to false', () async {
    final current = makeRoomState(
      isPlaying: true,
      startedAt: 1000,
      queue: [makeTrack()],
    );
    final pausedAt = DateTime.now().millisecondsSinceEpoch - 1000;
    await usecase(
      roomId: 'room1',
      current: current,
      isPlaying: false,
      pausedAt: pausedAt,
    );
    expect(repo.lastWrittenState?.isPlaying, isFalse);
  });

  test('resets startedAt when resuming (based on pausedAt)', () async {
    final current = makeRoomState(
      isPlaying: false,
      startedAt: 5000,
      pausedAt: 30000,
      queue: [makeTrack()],
    );
    await usecase(
      roomId: 'room1',
      current: current,
      isPlaying: true,
      pausedAt: 0,
    );
    // startedAt should be now - pausedAt, which is not the original 5000
    expect(repo.lastWrittenState?.startedAt, isNot(5000));
    expect(repo.lastWrittenState?.pausedAt, 0);
  });

  test('preserves startedAt and writes pausedAt when pausing', () async {
    final current = makeRoomState(
      isPlaying: true,
      startedAt: 5000,
      queue: [makeTrack()],
    );
    final pausedAt = 12000;
    await usecase(
      roomId: 'room1',
      current: current,
      isPlaying: false,
      pausedAt: pausedAt,
    );
    expect(repo.lastWrittenState?.startedAt, 5000);
    expect(repo.lastWrittenState?.pausedAt, 12000);
  });
}
