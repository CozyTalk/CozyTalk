import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/jukebox/domain/usecases/resolve_track.dart';

import '../../shared_fakes.dart';

void main() {
  late FakeJukeboxRepository repo;
  late ResolveTrack usecase;

  setUp(() {
    repo = FakeJukeboxRepository();
    usecase = ResolveTrack(repo);
  });

  test('forwards all params and returns track', () async {
    repo.resolveResult = makeTrack(id: '99');

    final result = await usecase(
      audiomackUrl: 'https://audiomack.com/a/song/s',
      addedBy: 'uid1',
      addedByName: 'Alice',
    );

    expect(repo.resolveCount, 1);
    expect(result.id, '99');
  });

  test('propagates exception from repository', () async {
    repo.error = Exception('not found');

    expect(
      () => usecase(
        audiomackUrl: 'https://audiomack.com/a/song/s',
        addedBy: 'uid1',
        addedByName: 'Alice',
      ),
      throwsException,
    );
  });
}
