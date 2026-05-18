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
    test('extracts artist and slug from audiomack URL', () async {
      datasource.trackResult = _makeTrackModel();

      await repo.resolveTrack(
        audiomackUrl: 'https://audiomack.com/myartist/song/myslug',
        addedBy: 'uid',
        addedByName: 'Alice',
      );

      expect(datasource.lastArtist, 'myartist');
      expect(datasource.lastSlug, 'myslug');
    });

    test('returns entity from model', () async {
      datasource.trackResult = _makeTrackModel(id: '99');

      final track = await repo.resolveTrack(
        audiomackUrl: 'https://audiomack.com/a/song/s',
        addedBy: 'uid',
        addedByName: 'User',
      );

      expect(track.id, '99');
    });

    test('throws on invalid host', () async {
      expect(
        () => repo.resolveTrack(
          audiomackUrl: 'https://example.com/a/song/s',
          addedBy: 'uid',
          addedByName: 'User',
        ),
        throwsException,
      );
    });

    test('throws when path is not /artist/song/slug', () async {
      expect(
        () => repo.resolveTrack(
          audiomackUrl: 'https://audiomack.com/a/album/s',
          addedBy: 'uid',
          addedByName: 'User',
        ),
        throwsException,
      );
    });

    test('throws when URL has fewer than 3 path segments', () async {
      expect(
        () => repo.resolveTrack(
          audiomackUrl: 'https://audiomack.com/a/song',
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
        queue: [],
      );

      await repo.writeJukeboxState(roomId: 'room1', roomState: state);

      expect(datasource.writeCount, 1);
      expect(datasource.lastWrittenState?['isPlaying'], isTrue);
      expect(datasource.lastWrittenState?['currentIndex'], 0);
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

JukeboxTrackModel _makeTrackModel({String id = '1'}) => JukeboxTrackModel(
  id: id,
  audiomackUrl: 'https://audiomack.com/a/song/s',
  embedUrl: 'https://audiomack.com/embed/a/song/s',
  streamingUrl: 'https://cdn.example.com/a.mp3',
  streamingUrlTimeout: 9999999999,
  title: 'Song',
  artist: 'Artist',
  artworkUrl: 'https://cdn.example.com/art.jpg',
  addedBy: 'uid',
  addedByName: 'User',
);

class _FakeDatasource implements JukeboxDatasource {
  JukeboxRoomStateModel? watchModel;
  JukeboxTrackModel? trackResult;
  int writeCount = 0;
  int clearCount = 0;
  Map<String, dynamic>? lastWrittenState;
  String? lastArtist;
  String? lastSlug;

  @override
  Stream<JukeboxRoomStateModel?> watchJukebox(String roomId) =>
      Stream.value(watchModel);

  @override
  Future<JukeboxTrackModel> fetchTrackMetadata({
    required String artist,
    required String slug,
    required String addedBy,
    required String addedByName,
  }) async {
    lastArtist = artist;
    lastSlug = slug;
    return trackResult!;
  }

  @override
  Future<String> fetchFreshStreamingUrl(String trackId) async =>
      'https://fresh.mp3';

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

  @override
  Future<void> reportPlayStats(String trackId) async {}
}
