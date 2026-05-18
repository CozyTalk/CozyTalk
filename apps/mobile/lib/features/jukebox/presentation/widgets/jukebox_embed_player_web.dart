import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

class JukeboxEmbedPlayer extends StatefulWidget {
  const JukeboxEmbedPlayer({
    super.key,
    required this.embedUrl,
    required this.trackId,
  });

  final String embedUrl;
  final String trackId;

  @override
  State<JukeboxEmbedPlayer> createState() => _JukeboxEmbedPlayerState();
}

class _JukeboxEmbedPlayerState extends State<JukeboxEmbedPlayer> {
  late final String _viewId;

  static final _registered = <String>{};

  @override
  void initState() {
    super.initState();
    _viewId = 'jukebox-embed-${widget.trackId}';
    if (_registered.add(_viewId)) {
      ui_web.platformViewRegistry.registerViewFactory(_viewId, (int id) {
        final iframe = web.HTMLIFrameElement();
        iframe.src = widget.embedUrl;
        iframe.allow = 'autoplay';
        iframe.allowFullscreen = true;
        iframe.style.border = 'none';
        iframe.style.width = '100%';
        iframe.style.height = '100%';
        return iframe;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(height: 150, child: HtmlElementView(viewType: _viewId));
  }
}
