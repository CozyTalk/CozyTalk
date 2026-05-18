import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/entities/jukebox_room_state.dart';
import 'jukebox_track_model.dart';

part 'jukebox_room_state_model.freezed.dart';
part 'jukebox_room_state_model.g.dart';

@freezed
abstract class JukeboxRoomStateModel with _$JukeboxRoomStateModel {
  const factory JukeboxRoomStateModel({
    required bool isPlaying,
    required int currentIndex,
    required int startedAt,
    required List<JukeboxTrackModel> queue,
  }) = _JukeboxRoomStateModel;

  factory JukeboxRoomStateModel.fromJson(Map<String, dynamic> json) =>
      _$JukeboxRoomStateModelFromJson(json);
}

extension JukeboxRoomStateModelX on JukeboxRoomStateModel {
  JukeboxRoomState toEntity() => JukeboxRoomState(
    isPlaying: isPlaying,
    currentIndex: currentIndex,
    startedAt: startedAt,
    queue: queue.map((t) => t.toEntity()).toList(),
  );
}
