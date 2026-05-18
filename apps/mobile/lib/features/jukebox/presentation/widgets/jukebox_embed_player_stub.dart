import 'package:flutter/widgets.dart';

class JukeboxEmbedPlayer extends StatelessWidget {
  const JukeboxEmbedPlayer({
    super.key,
    required this.embedUrl,
    required this.trackId,
  });

  final String embedUrl;
  final String trackId;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
