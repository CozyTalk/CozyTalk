import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/jukebox/data/datasources/jukebox_datasource.dart';
import 'package:mobile/features/jukebox/data/models/jukebox_room_state_model.dart';
import 'package:mobile/features/jukebox/data/models/jukebox_track_model.dart';
import 'package:mobile/features/jukebox/data/repositories/jukebox_repository_impl.dart';
import 'package:mobile/features/jukebox/domain/entities/jukebox_room_state.dart';

void main() {
  late _FakeDatasource datasource;
  late JukeboxRepositoryImpl repo;

  setUp(() {
    datasource = _FakeDatasource();
    repo = JukeboxRepositoryImpl(datasource);
  });

  group('resolveTrack', () {
    test('extracts videoId from youtube.com watch URL', () async {
      datasource.trackResult = _makeTrackModel();

      await repo.resolveTrack(
        youtubeUrl: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
        addedBy: 'uid',
        addedByName: 'Alice',
      );

      expect(datasource.lastVideoId, 'dQw4w9WgXcQ');
    });

    test('extracts videoId from youtu.be short URL', () async {
      datasource.trackResult = _makeTrackModel();

      await repo.resolveTrack(
        youtubeUrl: 'https://youtu.be/dQw4w9WgXcQ',
        addedBy: 'uid',
        addedByName: 'Alice',
      );

      expect(datasource.lastVideoId, 'dQw4w9WgXcQ');
    });

    test('returns entity from model', () async {
      datasource.trackResult = _makeTrackModel(id: '99');

      final track = await repo.resolveTrack(
        youtubeUrl: 'https://www.youtube.com/watch?v=99',
        addedBy: 'uid',
        addedByName: 'User',
      );

      expect(track.id, '99');
    });

    test('throws on non-YouTube URL', () async {
      expect(
        () => repo.resolveTrack(
          youtubeUrl: 'https://audiomack.com/artist/song/slug',
          addedBy: 'uid',
          addedByName: 'User',
        ),
        throwsException,
      );
    });

    test('throws when URL has no video ID', () async {
      expect(
        () => repo.resolveTrack(
          youtubeUrl: 'https://www.youtube.com/',
          addedBy: 'uid',
          addedByName: 'User',
        ),
        throwsException,
      );
    });
  });

  group('writeJukeboxState', () {
    test('serializes entity to map and calls writeState', () async {
      final state = JukeboxRoomState(
        isPlaying: true,
        currentIndex: 0,
        startedAt: 12345,
        pausedAt: 0,
        queue: [],
      );

      await repo.writeJukeboxState(roomId: 'room1', roomState: state);

      expect(datasource.writeCount, 1);
      expect(datasource.lastWrittenState?['isPlaying'], isTrue);
      expect(datasource.lastWrittenState?['currentIndex'], 0);
      expect(datasource.lastWrittenState?['pausedAt'], 0);
    });
  });

  group('clearJukebox', () {
    test('delegates to datasource clearState', () async {
      await repo.clearJukebox('room1');
      expect(datasource.clearCount, 1);
    });
  });

  group('watchJukebox', () {
    test('maps model to entity', () async {
      datasource.watchModel = JukeboxRoomStateModel(
        isPlaying: false,
        currentIndex: 0,
        startedAt: 0,
        queue: [],
      );

      final result = await repo.watchJukebox('room1').first;
      expect(result?.isPlaying, isFalse);
    });

    test('emits null when datasource emits null', () async {
      datasource.watchModel = null;
      final result = await repo.watchJukebox('room1').first;
      expect(result, isNull);
    });
  });
}

JukeboxTrackModel _makeTrackModel({String id = 'dQw4w9WgXcQ'}) =>
    JukeboxTrackModel(
      id: id,
      youtubeUrl: 'https://www.youtube.com/watch?v=$id',
      videoId: id,
      title: 'Song',
      artist: 'Artist',
      artworkUrl: 'https://i.ytimg.com/vi/$id/hqdefault.jpg',
      addedBy: 'uid',
      addedByName: 'User',
    );

class _FakeDatasource implements JukeboxDatasource {
  JukeboxRoomStateModel? watchModel;
  JukeboxTrackModel? trackResult;
  int writeCount = 0;
  int clearCount = 0;
  Map<String, dynamic>? lastWrittenState;
  String? lastVideoId;

  @override
  Stream<JukeboxRoomStateModel?> watchJukebox(String roomId) =>
      Stream.value(watchModel);

  @override
  Future<JukeboxTrackModel> fetchTrackMetadata({
    required String videoId,
    required String addedBy,
    required String addedByName,
  }) async {
    lastVideoId = videoId;
    return trackResult!;
  }

  @override
  Future<void> writeState({
    required String roomId,
    required Map<String, dynamic> state,
  }) async {
    writeCount++;
    lastWrittenState = state;
  }

  @override
  Future<void> clearState(String roomId) async => clearCount++;
}
