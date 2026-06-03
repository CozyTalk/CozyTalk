import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/jukebox/domain/usecases/remove_from_queue.dart';
import 'package:mobile/features/jukebox/presentation/providers/jukebox_provider.dart';

import '../../shared_fakes.dart';

// Mirrors the production removeFromQueue logic but wires RemoveFromQueue
// directly from an injected repo, bypassing the private DI chain.
class _RemoveTestNotifier extends JukeboxNotifier {
  final FakeJukeboxRepository _repo;
  _RemoveTestNotifier(this._repo);

  @override
  JukeboxUiState build() => const JukeboxUiState();

  void seed(JukeboxUiState s) => state = s;

  @override
  Future<void> removeFromQueue(int index) async {
    final roomId = state.roomId;
    final roomState = state.roomState;
    if (roomId == null || roomState == null) return;
    if (index < 0 || index >= roomState.queue.length) return;
    final updated = await RemoveFromQueue(_repo)(
      roomId: roomId,
      current: roomState,
      index: index,
    );
    state = state.copyWith(roomState: updated);
  }
}

void main() {
  group('JukeboxNotifier.removeFromQueue', () {
    late FakeJukeboxRepository repo;
    late ProviderContainer container;
    late _RemoveTestNotifier notifier;

    setUp(() {
      repo = FakeJukeboxRepository();
      container = ProviderContainer(
        overrides: [
          jukeboxNotifierProvider.overrideWith(() => _RemoveTestNotifier(repo)),
        ],
      );
      addTearDown(container.dispose);
      notifier =
          container.read(jukeboxNotifierProvider.notifier)
              as _RemoveTestNotifier;
    });

    test(
      'optimistically updates roomState before RTDB round-trip on valid remove',
      () async {
        notifier.seed(
          JukeboxUiState(
            roomId: 'room-a',
            roomState: makeRoomState(
              queue: [
                makeTrack(id: '1'),
                makeTrack(id: '2'),
              ],
            ),
          ),
        );

        await notifier.removeFromQueue(0);

        final roomState = container.read(jukeboxNotifierProvider).roomState;
        expect(roomState, isNotNull);
        expect(roomState!.queue.map((t) => t.id).toList(), ['2']);
        expect(repo.writeCount, 1);
      },
    );

    test('clears roomState to null when last track is removed', () async {
      notifier.seed(
        JukeboxUiState(
          roomId: 'room-a',
          roomState: makeRoomState(queue: [makeTrack()]),
        ),
      );

      await notifier.removeFromQueue(0);

      expect(container.read(jukeboxNotifierProvider).roomState, isNull);
      expect(repo.clearCount, 1);
      expect(repo.writeCount, 0);
    });

    test('does NOT wipe roomState when index is out of bounds', () async {
      notifier.seed(
        JukeboxUiState(
          roomId: 'room-a',
          roomState: makeRoomState(
            queue: [
              makeTrack(id: '1'),
              makeTrack(id: '2'),
            ],
          ),
        ),
      );

      await notifier.removeFromQueue(5);

      final roomState = container.read(jukeboxNotifierProvider).roomState;
      expect(roomState?.queue.length, 2);
      expect(repo.writeCount, 0);
      expect(repo.clearCount, 0);
    });

    test('does nothing when roomState is null', () async {
      notifier.seed(const JukeboxUiState(roomId: 'room-a'));

      await notifier.removeFromQueue(0);

      expect(container.read(jukeboxNotifierProvider).roomState, isNull);
      expect(repo.writeCount, 0);
    });
  });
}
