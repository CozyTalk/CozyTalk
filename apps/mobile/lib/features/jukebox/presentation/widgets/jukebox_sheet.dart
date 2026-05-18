import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/jukebox_provider.dart';
import 'jukebox_web_player.dart';
import 'queue_slot_tile.dart';

class JukeboxSheet extends ConsumerStatefulWidget {
  final String roomId;
  const JukeboxSheet({super.key, required this.roomId});

  @override
  ConsumerState<JukeboxSheet> createState() => _JukeboxSheetState();
}

class _JukeboxSheetState extends ConsumerState<JukeboxSheet> {
  final _urlController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Safety net: re-subscribe if JukeboxPlayer's subscription errored.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(jukeboxNotifierProvider.notifier).enterRoom(widget.roomId);
      }
    });
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(jukeboxNotifierProvider);
    final roomState = state.roomState;
    final notifier = ref.read(jukeboxNotifierProvider.notifier);

    ref.listen<JukeboxUiState>(jukeboxNotifierProvider, (_, next) {
      if (next.urlInput.isEmpty && _urlController.text.isNotEmpty) {
        _urlController.clear();
      }
    });

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, scrollController) => Column(
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(
                  Icons.queue_music_rounded,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Jukebox',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.close,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.all(16),
              children: [
                // ── Now Playing ──
                if (roomState?.currentTrack != null) ...[
                  const Text(
                    'NOW PLAYING',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Image.network(
                        roomState!.currentTrack!.artworkUrl,
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Icon(
                          Icons.music_note,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                    title: Text(
                      roomState.currentTrack!.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      roomState.currentTrack!.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  JukeboxWebPlayer(embedUrl: roomState.currentTrack!.embedUrl),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Semantics(
                        label: 'Skip track',
                        button: true,
                        child: IconButton(
                          iconSize: 36,
                          icon: Icon(
                            Icons.skip_next_rounded,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          onPressed: notifier.skip,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ] else ...[
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        'No track playing. Add one below.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  ),
                ],

                // ── Up Next ──
                const Text(
                  'UP NEXT',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                ...List.generate(3, (i) {
                  final queueIdx = (roomState?.currentIndex ?? 0) + 1 + i;
                  final track = (roomState?.queue.length ?? 0) > queueIdx
                      ? roomState!.queue[queueIdx]
                      : null;
                  if (track == null) {
                    return Container(
                      height: 56,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Empty slot',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                    );
                  }
                  return QueueSlotTile(
                    track: track,
                    onRemove: () => notifier.removeFromQueue(queueIdx),
                  );
                }),
                const SizedBox(height: 16),

                // ── Add Song ──
                const Text(
                  'ADD SONG',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _urlController,
                  onChanged: notifier.setUrlInput,
                  decoration: const InputDecoration(
                    hintText: 'audiomack.com/artist/song/slug',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                ),
                if (state.resolveError != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    state.resolveError!,
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (state.isResolving)
                      const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      Semantics(
                        label: 'Add song to queue',
                        button: true,
                        child: FilledButton.icon(
                          icon: const Icon(Icons.add),
                          label: const Text('Add URL'),
                          onPressed:
                              state.urlInput.trim().isNotEmpty &&
                                  !state.isResolving &&
                                  (roomState?.queue.length ?? 0) < 4
                              ? notifier.addUrl
                              : null,
                        ),
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
}
