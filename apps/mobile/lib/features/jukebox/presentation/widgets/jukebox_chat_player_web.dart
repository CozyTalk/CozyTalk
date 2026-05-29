import 'package:flutter/widgets.dart';

import 'jukebox_player.dart';

// Web keeps the original inline headless player — no floating UI.
class JukeboxChatPlayer extends StatelessWidget {
  final String roomId;
  const JukeboxChatPlayer({super.key, required this.roomId});

  @override
  Widget build(BuildContext context) => JukeboxPlayer(roomId: roomId);
}
