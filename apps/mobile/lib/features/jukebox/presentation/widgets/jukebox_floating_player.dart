import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/jukebox_provider.dart';
import 'jukebox_web_player.dart';

class JukeboxChatPlayer extends ConsumerStatefulWidget {
  final String roomId;
  const JukeboxChatPlayer({super.key, required this.roomId});

  @override
  ConsumerState<JukeboxChatPlayer> createState() => _JukeboxChatPlayerState();
}

class _JukeboxChatPlayerState extends ConsumerState<JukeboxChatPlayer> {
  late final JukeboxNotifier _notifier;
  final _overlayController = OverlayPortalController();
  Offset _position = const Offset(8, 80);

  static const double _width = 200;
  static const double _videoHeight = 113; // 16:9 at 200px
  static const double _barHeight = 28;

  @override
  void initState() {
    super.initState();
    _notifier = ref.read(jukeboxNotifierProvider.notifier);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _notifier.enterRoom(widget.roomId);
        _overlayController.show();
      }
    });
  }

  @override
  void dispose() {
    Future(() => _notifier.leaveRoom());
    super.dispose();
  }

  void _onPanUpdate(DragUpdateDetails d) {
    final size = MediaQuery.sizeOf(context);
    setState(() {
      _position = Offset(
        (_position.dx + d.delta.dx).clamp(0, size.width - _width),
        (_position.dy + d.delta.dy).clamp(
          0,
          size.height - _videoHeight - _barHeight,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return OverlayPortal(
      controller: _overlayController,
      overlayChildBuilder: (_) => Consumer(
        builder: (context, ref, _) {
          final rs = ref.watch(jukeboxNotifierProvider).roomState;
          final track = rs?.currentTrack;
          if (rs == null || track == null) return const SizedBox.shrink();
          return Positioned(
            left: _position.dx,
            top: _position.dy,
            width: _width,
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(10),
              clipBehavior: Clip.hardEdge,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanUpdate: _onPanUpdate,
                    child: Container(
                      height: _barHeight,
                      color: Colors.black87,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.drag_indicator,
                            color: Colors.white54,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              track.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(
                    height: _videoHeight,
                    child: JukeboxWebPlayer(
                      key: ValueKey(rs.currentIndex),
                      videoId: track.videoId,
                      startedAt: rs.startedAt,
                      pausedAt: rs.pausedAt,
                      isPlaying: rs.isPlaying,
                      onTrackEnded: _notifier.skip,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      child: const SizedBox.shrink(),
    );
  }
}
