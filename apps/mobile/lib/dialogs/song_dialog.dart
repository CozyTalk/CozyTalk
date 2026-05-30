import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../features/jukebox/domain/entities/jukebox_room_state.dart';
import '../features/jukebox/domain/entities/jukebox_track.dart';
import '../features/jukebox/presentation/providers/jukebox_provider.dart';
import '../features/jukebox/presentation/widgets/jukebox_web_player.dart';
import '../theme/app_colors.dart';

/// Slide-down song panel — rendered inside a Stack below the header.
class SongPanelBody extends ConsumerStatefulWidget {
  final VoidCallback onClose;
  final String roomId;

  const SongPanelBody({super.key, required this.onClose, required this.roomId});

  @override
  ConsumerState<SongPanelBody> createState() => _SongPanelBodyState();
}

class _SongPanelBodyState extends ConsumerState<SongPanelBody>
    with SingleTickerProviderStateMixin {
  final TextEditingController _inputCtrl = TextEditingController();
  late final AnimationController _spinCtrl;

  @override
  void initState() {
    super.initState();
    _spinCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(jukeboxNotifierProvider.notifier).enterRoom(widget.roomId);
      }
    });
  }

  @override
  void dispose() {
    _spinCtrl.dispose();
    _inputCtrl.dispose();
    super.dispose();
  }

  void _addSong() {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) return;
    ref.read(jukeboxNotifierProvider.notifier).addUrl(text);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(jukeboxNotifierProvider);
    final roomState = state.roomState;

    ref.listen<JukeboxUiState>(jukeboxNotifierProvider, (prev, next) {
      if (next.resolveError != null &&
          next.resolveError != prev?.resolveError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.resolveError!),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
      if (!next.isResolving &&
          next.resolveError == null &&
          next.urlInput.isEmpty &&
          _inputCtrl.text.isNotEmpty) {
        _inputCtrl.clear();
      }
    });

    final currentIndex = roomState?.currentIndex ?? 0;
    final queue = roomState?.queue ?? const <JukeboxTrack>[];
    final upNext = <({int index, JukeboxTrack track})>[
      for (
        int i = currentIndex + 1;
        i < queue.length && i < currentIndex + 4;
        i++
      )
        (index: i, track: queue[i]),
    ];

    return Container(
      color: AppColors.brownDeep,
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Now playing ──
          const Text(
            'Now playing',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          _nowPlayingCard(roomState, currentIndex),
          const SizedBox(height: 18),
          // ── Queue ──
          const Text(
            'Queue',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          _queueCard(upNext),
          const SizedBox(height: 14),
          // ── Input ──
          _inputRow(state.isResolving),
        ],
      ),
    );
  }

  Widget _nowPlayingCard(JukeboxRoomState? roomState, int currentIndex) {
    final track = roomState?.currentTrack;
    final notifier = ref.read(jukeboxNotifierProvider.notifier);

    if (track == null) {
      // No track: show spinning vinyl placeholder
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: _cardDecoration(),
        child: Row(
          children: [
            RotationTransition(
              turns: _spinCtrl,
              child: SvgPicture.asset(
                'assets/images/icons/musicdisk.svg',
                width: 44,
                height: 44,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                '—',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Track playing: show embedded YouTube video + title + controls
    return Container(
      decoration: _cardDecoration(),
      clipBehavior: Clip.hardEdge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Video player ──
          AspectRatio(
            aspectRatio: 16 / 9,
            child: JukeboxWebPlayer(
              key: ValueKey(currentIndex),
              videoId: track.videoId,
              startedAt: roomState!.startedAt,
              pausedAt: roomState.pausedAt,
              isPlaying: roomState.isPlaying,
              onTrackEnded: notifier.skip,
            ),
          ),
          // ── Track info + controls ──
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  track.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
                if (track.artist.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    track.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    _PlaybackPosition(
                      startedAt: roomState.startedAt,
                      pausedAt: roomState.pausedAt,
                      isPlaying: roomState.isPlaying,
                    ),
                    const Spacer(),
                    _controlBtn(
                      icon: roomState.isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      onTap: () => notifier.setPlaying(!roomState.isPlaying),
                    ),
                    const SizedBox(width: 8),
                    _controlBtn(
                      icon: Icons.skip_next_rounded,
                      onTap: notifier.skip,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _queueCard(List<({int index, JukeboxTrack track})> upNext) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 4),
      decoration: _cardDecoration(),
      child: upNext.isEmpty
          ? const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: Center(
                child: Text(
                  'Queue is empty',
                  style: TextStyle(fontSize: 13, color: Colors.black38),
                ),
              ),
            )
          : ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 190),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    for (int i = 0; i < upNext.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 28,
                              child: Text(
                                '${i + 1}.',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 15,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                upNext[i].track.title,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  height: 1.3,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            _xBtn(
                              onTap: () => ref
                                  .read(jukeboxNotifierProvider.notifier)
                                  .removeFromQueue(upNext[i].index),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
    );
  }

  BoxDecoration _cardDecoration() => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(18),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.08),
        blurRadius: 6,
        offset: const Offset(0, 2),
      ),
    ],
  );

  Widget _xBtn({required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: const Color(0xFFFFCCAA),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFCF5733), width: 1.5),
        ),
        child: const Icon(Icons.close, color: Color(0xFFCF5733), size: 16),
      ),
    );
  }

  Widget _controlBtn({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: const Color(0xFFEAC163),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }

  Widget _inputRow(bool isResolving) {
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: TextField(
              controller: _inputCtrl,
              style: const TextStyle(fontSize: 14),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _addSong(),
              decoration: InputDecoration(
                hintText: 'Type here..',
                hintStyle: const TextStyle(color: Colors.black38, fontSize: 14),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(28),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: isResolving ? null : _addSong,
          child: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: isResolving
                  ? Colors.grey.shade400
                  : const Color(0xFFEAC163),
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: isResolving
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : SvgPicture.asset(
                    'assets/images/icons/sent.svg',
                    width: 24,
                    height: 24,
                  ),
          ),
        ),
      ],
    );
  }
}

// ── Live playback position ─────────────────────────────────────────────────────

class _PlaybackPosition extends StatefulWidget {
  final int startedAt;
  final int pausedAt;
  final bool isPlaying;

  const _PlaybackPosition({
    required this.startedAt,
    required this.pausedAt,
    required this.isPlaying,
  });

  @override
  State<_PlaybackPosition> createState() => _PlaybackPositionState();
}

class _PlaybackPositionState extends State<_PlaybackPosition> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void didUpdateWidget(_PlaybackPosition old) {
    super.didUpdateWidget(old);
    if (old.isPlaying != widget.isPlaying ||
        old.startedAt != widget.startedAt) {
      _startTimer();
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = null;
    if (widget.isPlaying) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rawSecs = widget.isPlaying
        ? (DateTime.now().millisecondsSinceEpoch - widget.startedAt) ~/ 1000
        : widget.pausedAt ~/ 1000;
    final secs = rawSecs.clamp(0, 86400);
    final m = secs ~/ 60;
    final s = secs % 60;
    return Text(
      '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}',
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Colors.black54,
      ),
    );
  }
}

/// Stub kept so any leftover import doesn't break.
class SongDialog extends StatelessWidget {
  const SongDialog({super.key});
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
