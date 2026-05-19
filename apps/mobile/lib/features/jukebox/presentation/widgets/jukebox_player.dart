import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/jukebox_provider.dart';
import 'jukebox_web_player.dart';

class JukeboxPlayer extends ConsumerStatefulWidget {
  final String roomId;
  const JukeboxPlayer({super.key, required this.roomId});

  @override
  ConsumerState<JukeboxPlayer> createState() => _JukeboxPlayerState();
}

class _JukeboxPlayerState extends ConsumerState<JukeboxPlayer> {
  late final JukeboxNotifier _notifier;

  @override
  void initState() {
    super.initState();
    _notifier = ref.read(jukeboxNotifierProvider.notifier);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _notifier.enterRoom(widget.roomId);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.addPostFrameCallback((_) => _notifier.leaveRoom());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final roomState = ref.watch(jukeboxNotifierProvider).roomState;

    if (roomState?.currentTrack == null) return const SizedBox.shrink();

    // Keep the embed mounted in the chat body so it is never destroyed when
    // the sheet opens/closes.
    // ValueKey on currentIndex ensures Flutter recreates the player on every
    // skip — even when the same videoId appears again in the queue.
    return JukeboxWebPlayer(
      key: ValueKey(roomState!.currentIndex),
      videoId: roomState.currentTrack!.videoId,
      startedAt: roomState.startedAt,
      pausedAt: roomState.pausedAt,
      isPlaying: roomState.isPlaying,
      onTrackEnded: _notifier.skip,
    );
  }
}
