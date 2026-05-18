import 'package:mobile/features/jukebox/domain/entities/jukebox_room_state.dart';
import 'package:mobile/features/jukebox/domain/entities/jukebox_track.dart';
import 'package:mobile/features/jukebox/domain/repositories/jukebox_repository.dart';

JukeboxTrack makeTrack({
  String id = '1',
  String title = 'Song',
  String artist = 'Artist',
  String addedBy = 'uid',
  int streamingUrlTimeout = 9999999999,
}) => JukeboxTrack(
  id: id,
  audiomackUrl: 'https://audiomack.com/a/song/s',
  embedUrl: 'https://audiomack.com/embed/a/song/s',
  streamingUrl: 'https://cdn.example.com/a.mp3',
  streamingUrlTimeout: streamingUrlTimeout,
  title: title,
  artist: artist,
  artworkUrl: 'https://cdn.example.com/art.jpg',
  addedBy: addedBy,
  addedByName: 'User',
);

JukeboxRoomState makeRoomState({
  bool isPlaying = false,
  int currentIndex = 0,
  int startedAt = 0,
  List<JukeboxTrack>? queue,
}) => JukeboxRoomState(
  isPlaying: isPlaying,
  currentIndex: currentIndex,
  startedAt: startedAt,
  queue: queue ?? [],
);

class FakeJukeboxRepository implements JukeboxRepository {
  JukeboxRoomState? watchValue;
  Exception? error;
  int watchCount = 0;
  int resolveCount = 0;
  int writeCount = 0;
  int clearCount = 0;
  JukeboxTrack? resolveResult;
  JukeboxRoomState? lastWrittenState;

  @override
  Stream<JukeboxRoomState?> watchJukebox(String roomId) {
    watchCount++;
    if (error != null) return Stream.error(error!);
    return Stream.value(watchValue);
  }

  @override
  Future<JukeboxTrack> resolveTrack({
    required String audiomackUrl,
    required String addedBy,
    required String addedByName,
  }) async {
    resolveCount++;
    if (error != null) throw error!;
    return resolveResult!;
  }

  @override
  Future<String> refreshStreamingUrl(String trackId) async =>
      'https://fresh.mp3';

  @override
  Future<void> writeJukeboxState({
    required String roomId,
    required JukeboxRoomState roomState,
  }) async {
    writeCount++;
    lastWrittenState = roomState;
    if (error != null) throw error!;
  }

  @override
  Future<void> clearJukebox(String roomId) async => clearCount++;
}
