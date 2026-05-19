import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/jukebox/domain/usecases/watch_jukebox.dart';

import '../../shared_fakes.dart';

void main() {
  late FakeJukeboxRepository repo;
  late WatchJukebox usecase;

  setUp(() {
    repo = FakeJukeboxRepository();
    usecase = WatchJukebox(repo);
  });

  test('delegates to repository and increments watchCount', () async {
    final track = makeTrack();
    repo.watchValue = makeRoomState(queue: [track]);

    final result = await usecase('room1').first;

    expect(repo.watchCount, 1);
    expect(result?.queue.first.id, track.id);
  });

  test('returns null when repository emits null', () async {
    repo.watchValue = null;
    final result = await usecase('room1').first;
    expect(result, isNull);
  });
}
