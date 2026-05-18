import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/jukebox_provider.dart';

class JukeboxPlayer extends ConsumerWidget {
  final String roomId;
  const JukeboxPlayer({super.key, required this.roomId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(jukeboxNotifierProvider.notifier).enterRoom(roomId);
    });
    return const SizedBox.shrink();
  }
}
