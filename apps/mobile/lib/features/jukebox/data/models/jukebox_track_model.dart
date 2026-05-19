import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/entities/jukebox_track.dart';

part 'jukebox_track_model.freezed.dart';
part 'jukebox_track_model.g.dart';

@freezed
abstract class JukeboxTrackModel with _$JukeboxTrackModel {
  const factory JukeboxTrackModel({
    required String id,
    required String youtubeUrl,
    required String videoId,
    required String title,
    required String artist,
    required String artworkUrl,
    required String addedBy,
    required String addedByName,
  }) = _JukeboxTrackModel;

  factory JukeboxTrackModel.fromJson(Map<String, dynamic> json) =>
      _$JukeboxTrackModelFromJson(json);
}

extension JukeboxTrackModelX on JukeboxTrackModel {
  JukeboxTrack toEntity() => JukeboxTrack(
    id: id,
    youtubeUrl: youtubeUrl,
    videoId: videoId,
    title: title,
    artist: artist,
    artworkUrl: artworkUrl,
    addedBy: addedBy,
    addedByName: addedByName,
  );
}
