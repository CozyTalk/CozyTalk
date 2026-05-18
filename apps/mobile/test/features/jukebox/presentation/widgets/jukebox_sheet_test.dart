import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/jukebox/domain/entities/jukebox_room_state.dart';
import 'package:mobile/features/jukebox/domain/entities/jukebox_track.dart';
import 'package:mobile/features/jukebox/presentation/providers/jukebox_provider.dart';
import 'package:mobile/features/jukebox/presentation/widgets/jukebox_sheet.dart';
import 'package:mobile/features/jukebox/presentation/widgets/queue_slot_tile.dart';

class _FakeJukeboxNotifier extends JukeboxNotifier {
  final JukeboxUiState _initial;
  int addUrlCount = 0;
  int skipCount = 0;
  int removeCount = 0;
  int? lastRemovedIndex;
  bool? lastSetPlaying;

  _FakeJukeboxNotifier({JukeboxUiState initial = const JukeboxUiState()})
    : _initial = initial;

  @override
  JukeboxUiState build() => _initial;

  @override
  void enterRoom(String roomId) {}

  @override
  Future<void> addUrl(String url) async => addUrlCount++;

  @override
  Future<void> skip() async => skipCount++;

  @override
  Future<void> setPlaying(bool v) async => lastSetPlaying = v;

  @override
  Future<void> removeFromQueue(int index) async {
    removeCount++;
    lastRemovedIndex = index;
  }
}

Widget _buildSheet(_FakeJukeboxNotifier fake) {
  return ProviderScope(
    overrides: [jukeboxNotifierProvider.overrideWith(() => fake)],
    child: const MaterialApp(
      home: Scaffold(body: JukeboxSheet(roomId: 'room1')),
    ),
  );
}

const _track = JukeboxTrack(
  id: '1',
  audiomackUrl: 'https://audiomack.com/a/song/s',
  embedUrl: 'https://audiomack.com/embed/a/song/s',
  streamingUrl: 'https://cdn.example.com/a.mp3',
  streamingUrlTimeout: 9999999999,
  title: 'My Song',
  artist: 'My Artist',
  artworkUrl: 'https://cdn.example.com/art.jpg',
  addedBy: 'uid',
  addedByName: 'User',
);

void main() {
  testWidgets('renders empty state with no track playing', (tester) async {
    final fake = _FakeJukeboxNotifier();
    await tester.pumpWidget(_buildSheet(fake));
    expect(find.text('No track playing. Add one below.'), findsOneWidget);
    expect(find.text('UP NEXT'), findsOneWidget);
    expect(find.text('ADD SONG', skipOffstage: false), findsOneWidget);
  });

  testWidgets('shows track title and artist when playing', (tester) async {
    final roomState = JukeboxRoomState(
      isPlaying: true,
      currentIndex: 0,
      startedAt: 0,
      queue: [_track],
    );
    final fake = _FakeJukeboxNotifier(
      initial: JukeboxUiState(roomId: 'room1', roomState: roomState),
    );
    await tester.pumpWidget(_buildSheet(fake));
    expect(find.text('My Song'), findsOneWidget);
    expect(find.text('My Artist'), findsOneWidget);
  });

  testWidgets('skip button calls skip()', (tester) async {
    final roomState = JukeboxRoomState(
      isPlaying: true,
      currentIndex: 0,
      startedAt: 0,
      queue: [_track],
    );
    final fake = _FakeJukeboxNotifier(
      initial: JukeboxUiState(roomId: 'room1', roomState: roomState),
    );
    await tester.pumpWidget(_buildSheet(fake));

    await tester.tap(find.byIcon(Icons.skip_next_rounded));
    expect(fake.skipCount, 1);
  });

  testWidgets('remove button calls removeFromQueue with correct index', (
    tester,
  ) async {
    const queueTrack = JukeboxTrack(
      id: '2',
      audiomackUrl: 'https://audiomack.com/a/song/s2',
      embedUrl: 'https://audiomack.com/embed/a/song/s2',
      streamingUrl: 'https://cdn.example.com/b.mp3',
      streamingUrlTimeout: 9999999999,
      title: 'Queued Track',
      artist: 'Artist 2',
      artworkUrl: 'https://cdn.example.com/art2.jpg',
      addedBy: 'uid',
      addedByName: 'User',
    );
    final roomState = JukeboxRoomState(
      isPlaying: true,
      currentIndex: 0,
      startedAt: 0,
      queue: [_track, queueTrack],
    );
    final fake = _FakeJukeboxNotifier(
      initial: JukeboxUiState(roomId: 'room1', roomState: roomState),
    );
    await tester.pumpWidget(_buildSheet(fake));
    // Scroll down to ensure the UP NEXT slot is rendered
    await tester.drag(find.byType(ListView), const Offset(0, -120));
    await tester.pump();

    final tileCloseBtn = find.descendant(
      of: find.byType(QueueSlotTile),
      matching: find.byIcon(Icons.close),
    );
    expect(tileCloseBtn, findsOneWidget);
    await tester.tap(tileCloseBtn);
    await tester.pump();
    expect(fake.removeCount, 1);
    expect(fake.lastRemovedIndex, 1);
  });

  testWidgets('shows spinner when isResolving', (tester) async {
    final fake = _FakeJukeboxNotifier(
      initial: const JukeboxUiState(isResolving: true),
    );
    await tester.pumpWidget(_buildSheet(fake));
    expect(
      find.byType(CircularProgressIndicator, skipOffstage: false),
      findsOneWidget,
    );
  });

  testWidgets('shows resolveError text', (tester) async {
    final fake = _FakeJukeboxNotifier(
      initial: const JukeboxUiState(resolveError: 'Invalid URL'),
    );
    await tester.pumpWidget(_buildSheet(fake));
    expect(find.text('Invalid URL', skipOffstage: false), findsOneWidget);
  });

  testWidgets('Add URL button disabled when urlInput is empty', (tester) async {
    final fake = _FakeJukeboxNotifier(
      initial: const JukeboxUiState(urlInput: ''),
    );
    await tester.pumpWidget(_buildSheet(fake));

    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Add URL', skipOffstage: false),
    );
    expect(button.onPressed, isNull);
  });
}
