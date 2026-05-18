import 'dart:convert';

import 'package:firebase_database/firebase_database.dart';
import 'package:http/http.dart' as http;

import '../models/jukebox_room_state_model.dart';
import '../models/jukebox_track_model.dart';

abstract class JukeboxDatasource {
  Stream<JukeboxRoomStateModel?> watchJukebox(String roomId);

  Future<JukeboxTrackModel> fetchTrackMetadata({
    required String artist,
    required String slug,
    required String addedBy,
    required String addedByName,
  });

  Future<String> fetchFreshStreamingUrl(String trackId);

  Future<void> writeState({
    required String roomId,
    required Map<String, dynamic> state,
  });

  Future<void> clearState(String roomId);

  Future<void> reportPlayStats(String trackId);
}

class JukeboxDatasourceImpl implements JukeboxDatasource {
  final FirebaseDatabase _rtdb;
  static const _base = 'https://api.audiomack.com/v1';

  JukeboxDatasourceImpl(this._rtdb);

  @override
  Stream<JukeboxRoomStateModel?> watchJukebox(String roomId) {
    return _rtdb.ref('jukebox/$roomId').onValue.map((event) {
      if (!event.snapshot.exists || event.snapshot.value == null) return null;
      final raw = Map<String, dynamic>.from(event.snapshot.value as Map);
      // RTDB may return a sparse Map keyed by numeric strings instead of a List
      // when the array has been mutated — normalize it before passing to fromJson.
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
      } else if (queueRaw == null) {
        raw['queue'] = <dynamic>[];
      }
      return JukeboxRoomStateModel.fromJson(raw);
    });
  }

  @override
  Future<JukeboxTrackModel> fetchTrackMetadata({
    required String artist,
    required String slug,
    required String addedBy,
    required String addedByName,
  }) async {
    final uri = Uri.parse('$_base/music/song/$artist/$slug');
    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Audiomack API error ${response.statusCode}');
    }
    final data = Map<String, dynamic>.from(jsonDecode(response.body) as Map);
    final id = data['id'].toString();
    return JukeboxTrackModel(
      id: id,
      audiomackUrl: 'https://audiomack.com/$artist/song/$slug',
      embedUrl: 'https://audiomack.com/embed/$artist/song/$slug',
      streamingUrl: data['streaming_url'] as String,
      streamingUrlTimeout: (data['streaming_url_timeout'] as num).toInt(),
      title: data['title'] as String,
      artist: data['artist'] as String,
      artworkUrl: data['image'] as String,
      addedBy: addedBy,
      addedByName: addedByName,
    );
  }

  @override
  Future<String> fetchFreshStreamingUrl(String trackId) async {
    final response = await http.post(Uri.parse('$_base/music/$trackId/play'));
    if (response.statusCode != 200) {
      throw Exception('Failed to fetch streaming URL: ${response.statusCode}');
    }
    return response.body.trim();
  }

  @override
  Future<void> writeState({
    required String roomId,
    required Map<String, dynamic> state,
  }) => _rtdb.ref('jukebox/$roomId').set(state);

  @override
  Future<void> clearState(String roomId) =>
      _rtdb.ref('jukebox/$roomId').remove();

  @override
  Future<void> reportPlayStats(String trackId) async {
    try {
      final tokenResp = await http.get(
        Uri.parse(
          '$_base/music/stats/token?device=anonymous&music_id=$trackId',
        ),
      );
      if (tokenResp.statusCode != 200) return;
      final token = (jsonDecode(tokenResp.body) as Map)['token'] as String?;
      if (token == null) return;
      await http.post(
        Uri.parse('$_base/music/stats/$trackId'),
        body: 'token=$token&type=play',
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      );
    } catch (_) {
      // fire-and-forget — never rethrow
    }
  }
}
