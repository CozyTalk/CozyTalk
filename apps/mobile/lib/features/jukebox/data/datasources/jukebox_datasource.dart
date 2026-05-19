import 'dart:convert';

import 'package:firebase_database/firebase_database.dart';
import 'package:http/http.dart' as http;

import '../models/jukebox_room_state_model.dart';
import '../models/jukebox_track_model.dart';

abstract class JukeboxDatasource {
  Stream<JukeboxRoomStateModel?> watchJukebox(String roomId);

  Future<JukeboxTrackModel> fetchTrackMetadata({
    required String videoId,
    required String addedBy,
    required String addedByName,
  });

  Future<void> writeState({
    required String roomId,
    required Map<String, dynamic> state,
  });

  Future<void> clearState(String roomId);
}

class JukeboxDatasourceImpl implements JukeboxDatasource {
  final FirebaseDatabase _rtdb;

  JukeboxDatasourceImpl(this._rtdb);

  @override
  Stream<JukeboxRoomStateModel?> watchJukebox(String roomId) {
    return _rtdb.ref('jukebox/$roomId').onValue.map((event) {
      if (!event.snapshot.exists || event.snapshot.value == null) return null;
      final raw = Map<String, dynamic>.from(event.snapshot.value as Map);
      // RTDB may return the queue as a sparse Map (numeric string keys) or a
      // List depending on the platform / how the array was mutated.  On Flutter
      // Web the JS SDK returns it as a List<dynamic> where each element is a
      // Map<dynamic,dynamic> — normalize every path to List<Map<String,dynamic>>
      // before passing to Freezed fromJson which expects Map<String,dynamic>.
      final queueRaw = raw['queue'];
      if (queueRaw is Map) {
        final entries = queueRaw.entries.toList()
          ..sort(
            (a, b) => int.parse(
              a.key.toString(),
            ).compareTo(int.parse(b.key.toString())),
          );
        raw['queue'] = entries
            .map((e) => Map<String, dynamic>.from(e.value as Map))
            .toList();
      } else if (queueRaw is List) {
        // Flutter Web returns plain JS arrays; each item may be Map<dynamic,dynamic>.
        raw['queue'] = queueRaw
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
      } else {
        raw['queue'] = <dynamic>[];
      }
      return JukeboxRoomStateModel.fromJson(raw);
    });
  }

  @override
  Future<JukeboxTrackModel> fetchTrackMetadata({
    required String videoId,
    required String addedBy,
    required String addedByName,
  }) async {
    final watchUrl = 'https://www.youtube.com/watch?v=$videoId';
    final encoded = Uri.encodeComponent(watchUrl);
    final uri = Uri.parse(
      'https://www.youtube.com/oembed?url=$encoded&format=json',
    );
    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw Exception('YouTube oEmbed ${response.statusCode}');
    }
    final data = Map<String, dynamic>.from(jsonDecode(response.body) as Map);
    final thumbnailUrl =
        (data['thumbnail_url'] as String?) ??
        'https://i.ytimg.com/vi/$videoId/hqdefault.jpg';
    return JukeboxTrackModel(
      id: videoId,
      youtubeUrl: watchUrl,
      videoId: videoId,
      title: data['title'] as String,
      artist: data['author_name'] as String,
      artworkUrl: thumbnailUrl,
      addedBy: addedBy,
      addedByName: addedByName,
    );
  }

  @override
  Future<void> writeState({
    required String roomId,
    required Map<String, dynamic> state,
  }) => _rtdb.ref('jukebox/$roomId').set(state);

  @override
  Future<void> clearState(String roomId) =>
      _rtdb.ref('jukebox/$roomId').remove();
}
