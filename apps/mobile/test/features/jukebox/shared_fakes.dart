import 'package:mobile/features/jukebox/domain/entities/jukebox_room_state.dart';
import 'package:mobile/features/jukebox/domain/entities/jukebox_track.dart';
import 'package:mobile/features/jukebox/domain/repositories/jukebox_repository.dart';

JukeboxTrack makeTrack({
  String id = '1',
  String title = 'Song',
  String artist = 'Artist',
  String addedBy = 'uid',
}) => JukeboxTrack(
  id: id,
  youtubeUrl: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
  videoId: 'dQw4w9WgXcQ',
  title: title,
  artist: artist,
  artworkUrl: 'https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg',
  addedBy: addedBy,
  addedByName: 'User',
);

JukeboxRoomState makeRoomState({
  bool isPlaying = false,
  int currentIndex = 0,
  int startedAt = 0,
  int pausedAt = 0,
  List<JukeboxTrack>? queue,
}) => JukeboxRoomState(
  isPlaying: isPlaying,
  currentIndex: currentIndex,
  startedAt: startedAt,
  pausedAt: pausedAt,
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
    required String youtubeUrl,
    required String addedBy,
    required String addedByName,
  }) async {
    resolveCount++;
    if (error != null) throw error!;
    return resolveResult!;
  }

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
