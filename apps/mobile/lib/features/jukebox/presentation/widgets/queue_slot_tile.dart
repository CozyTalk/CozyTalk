import 'package:flutter/material.dart';

import '../../domain/entities/jukebox_track.dart';

class QueueSlotTile extends StatelessWidget {
  final JukeboxTrack track;
  final VoidCallback onRemove;
  const QueueSlotTile({super.key, required this.track, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Image.network(
          track.artworkUrl,
          width: 48,
          height: 48,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => const Icon(Icons.music_note),
        ),
      ),
      title: Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        track.artist,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Semantics(
        label: 'Remove ${track.title} from queue',
        button: true,
        child: IconButton(icon: const Icon(Icons.close), onPressed: onRemove),
      ),
    );
  }
}
